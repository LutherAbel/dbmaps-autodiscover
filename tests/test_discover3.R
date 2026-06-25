# RED (Iteration 3): self-table spurious match + parent disambiguation.
root <- Sys.getenv("DBMAPS_ROOT", ".")
source(file.path(root, "R", "discover.R"))
suppressMessages(library(data.table))

mk_db <- function(tabs) list(
  data = tabs, cols = lapply(tabs, names),
  types = lapply(tabs, function(t) vapply(t, function(x) class(x)[1], character(1))))

# Two parents share key name "store_id"; child store_id must bind to STORE (table
# affinity), not staff.
store    <- data.table(store_id = 1:2, mgr = c("x","y"))
staff    <- data.table(staff_id = 1:2, store_id = c(1, 2))      # store_id unique here too
customer <- data.table(customer_id = 1:6, store_id = c(1,1,2,2,1,2),
                       address_id = 11:16)                       # address_id unique, id-named
# Self-table coincidence: payment_id (1:10) value-contained in rental_id (1:10).
payment  <- data.table(payment_id = 1:10, rental_id = 1:10, amt = runif(10))
db <- mk_db(list(store = store, staff = staff, customer = customer, payment = payment))

pred <- discover_joins(db)
cat("predicted pairs:\n"); print(pred)
has <- function(tf,cf,tt,ct) any(
  (pred$table_from==tf & pred$col_from==cf & pred$table_to==tt & pred$col_to==ct) |
  (pred$table_from==tt & pred$col_from==ct & pred$table_to==tf & pred$col_to==cf))

stopifnot("customer.store_id should bind to store.store_id" =
            has("customer","store_id","store","store_id"))
stopifnot("customer.store_id wrongly bound to staff.store_id" =
            !has("customer","store_id","staff","store_id"))
stopifnot("self-table payment_id<->rental_id wrongly predicted" =
            !has("payment","payment_id","payment","rental_id"))
stopifnot("self-table customer_id<->address_id wrongly predicted" =
            !has("customer","customer_id","customer","address_id"))
cat("TEST PASSED: test_discover3\n")
