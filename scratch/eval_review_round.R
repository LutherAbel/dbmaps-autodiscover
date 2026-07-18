# Measure the review-round changes: (a) regression check without aliases,
# (b) recall gain with a 3-entry alias map for the semantic FK names.
root <- "."
source(file.path(root, "R", "groundtruth.R"))
source(file.path(root, "R", "evaluate.R"))
source(file.path(root, "R", "discover.R"))

dbs <- list(chinook = "Chinook_Sqlite.sqlite", sakila = "sakila.db",
            northwind = "northwind.db")
aliases <- list(reportsto = "employeeid", supportrepid = "employeeid",
                shipvia = "shipperid")

run <- function(label, alias_map) {
  pooled <- list()
  for (dbn in names(dbs)) {
    db <- load_sqlite_db(file.path(root, "data-raw", dbs[[dbn]]))
    res <- evaluate(discover_joins(db, alias_map = alias_map), db$truth,
                    count_universe(db$cols))
    cat(sprintf("  %-10s prec=%.3f recall=%.3f (TP=%d FP=%d FN=%d)\n",
                dbn, res$precision, res$recall, res$tp, res$fp, res$fn))
    pooled[[dbn]] <- res
  }
  p <- evaluate_pooled(pooled)
  cat(sprintf("  POOLED     prec=%.3f recall=%.3f (TP=%d FP=%d FN=%d)\n\n",
              p$precision, p$recall, p$tp, p$fp, p$fn))
}

cat("== no alias_map (regression check vs 1.000/0.848) ==\n")
run("plain", list())
cat("== with alias_map (reportsto/supportrepid/shipvia) ==\n")
run("alias", aliases)
