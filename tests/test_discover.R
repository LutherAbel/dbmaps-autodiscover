# RED: discover_joins must find a real FK by value containment while rejecting a
# same-named non-key column (the trap that wrecked the exact-name baseline).
root <- Sys.getenv("DBMAPS_ROOT", ".")
source(file.path(root, "R", "discover.R"))
suppressMessages(library(data.table))

mk_db <- function(tabs) {
  list(
    data  = tabs,
    cols  = lapply(tabs, names),
    types = lapply(tabs, function(t) vapply(t, function(x) class(x)[1], character(1)))
  )
}

# customers(customer_id PK, name); orders(order_id PK, customer_id FK, name)
# 'name' is shared but is NOT a key -> must be rejected.
# orders.customer_id values all in customers.customer_id -> real FK.
customers <- data.table(customer_id = 1:5, name = c("a","b","c","d","e"))
orders    <- data.table(order_id = 101:106,
                        customer_id = c(1,2,2,3,5,5),
                        name = c("p","q","q","r","s","s"))
db <- mk_db(list(customers = customers, orders = orders))

pred <- discover_joins(db)
cat("predicted pairs:\n"); print(pred)

has_fk <- any(
  grepl("customer_id", pred$col_from) & grepl("customer_id", pred$col_to) &
  ((pred$table_from == "orders" & pred$table_to == "customers") |
   (pred$table_from == "customers" & pred$table_to == "orders")))
has_name_trap <- any(pred$col_from == "name" & pred$col_to == "name")

stopifnot("real FK (orders.customer_id -> customers.customer_id) not found" = has_fk)
stopifnot("name<->name false positive present" = !has_name_trap)
cat("TEST PASSED: test_discover\n")
