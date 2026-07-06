# Minimal reproducer for DBmaps issue: map_join_paths() data-driven discovery
# fails with "Unsupported type raw" on any database containing BLOB columns.
#
# Root cause: DBI/RSQLite returns BLOBs as `blob` class columns (vctrs-based:
# blob > vctrs_list_of > vctrs_vctr > list). anyDuplicated()/unique() dispatch
# to vctrs methods, whose C code does not support the raw type. Real-world
# trigger: Northwind's Employees$Photo / Categories$Picture.
#
# Two-line core:
#   blob_col <- blob::blob(as.raw(1:4))
#   anyDuplicated(blob_col)   # Error: Unsupported type raw
#
# Suggested fix (confirmed to work, since blob inherits from list): skip
# non-atomic columns in the scanner, e.g.
#   if (is.list(dt[[col_name]])) next

library(DBmaps)
library(data.table)

parent <- data.table(
  parent_id = 1:3,
  photo     = blob::blob(as.raw(1:4), as.raw(5:8), as.raw(9:12))  # as RSQLite returns BLOBs
)
child <- data.table(child_id = 1:6, parent_id = c(1, 2, 3, 1, 2, 3))

meta <- table_info(
  "parent", "parent_id", "parent_id",
  list(list(OutcomeName = "n", ValueExpression = quote(parent_id),
            AggregationMethods = list(list(AggregatedName = "cnt",
              AggregationFunction = "length", GroupingVariables = "parent_id")))))

# Control: without the blob column the child->parent join is found.
ok <- map_join_paths(meta, data_list = list(parent = parent[, .(parent_id)], child = child))
cat("control (no blob column):", nrow(ok), "join(s) found\n")

# With the blob column: hard failure, no joins discoverable at all.
res <- map_join_paths(meta, data_list = list(parent = parent, child = child))
cat("with blob column:", nrow(res), "join(s) found\n")
