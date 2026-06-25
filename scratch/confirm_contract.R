# Confirm the exact DBmaps registry contract by live introspection.
# Hard Constraint #2: pin the structure, do not invent it.
suppressMessages(library(DBmaps))
suppressMessages(library(data.table))

cat("================ table_info() output structure ================\n")
cust_meta <- table_info(
  table_name        = "customers",
  source_identifier = "customer_id",
  identifier_columns = "customer_id",
  key_outcome_specs = list(list(
    OutcomeName = "income",
    ValueExpression = quote(income),
    AggregationMethods = list(list(
      AggregatedName = "avg_income",
      AggregationFunction = "mean",
      GroupingVariables = "region"
    ))
  ))
)
print(str(cust_meta))
cat("\ncolumns:", paste(names(cust_meta), collapse=", "), "\n")

cat("\n================ registry assembly ================\n")
reg <- create_metadata_registry()
reg <- add_table(reg, cust_meta)
cat("registry class:", paste(class(reg), collapse=","), "  nrow:", nrow(reg), "\n")

cat("\n================ map_join_paths MODE 2 (data-driven, no metadata) ================\n")
# This is DBmaps' OWN auto-discoverer. It is a baseline we must beat.
data_list <- list(
  customers    = as.data.table(customers),
  products     = as.data.table(products),
  transactions = as.data.table(transactions)
)
# Mode 2 needs a metadata_dt argument but uses data_list for discovery.
empty_meta <- table_info("customers","customer_id","customer_id",
  list(list(OutcomeName="x", ValueExpression=quote(income),
    AggregationMethods=list(list(AggregatedName="a",AggregationFunction="mean",GroupingVariables="region")))))
m2 <- map_join_paths(empty_meta, data_list = data_list)
cat("Mode 2 discovered join pairs:\n")
print(m2)
