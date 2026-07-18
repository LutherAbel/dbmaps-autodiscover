# Per-DB detail for the CURRENT (with-stringdist) discoverer, to correct eval_log.
root <- "."
source(file.path(root, "R", "groundtruth.R"))
source(file.path(root, "R", "evaluate.R"))
source(file.path(root, "R", "discover.R"))
dbs <- list(chinook="Chinook_Sqlite.sqlite", sakila="sakila.db", northwind="northwind.db")
pooled <- list()
for (dbn in names(dbs)) {
  db <- load_sqlite_db(file.path(root, "data-raw", dbs[[dbn]]))
  res <- evaluate(discover_joins(db), db$truth, count_universe(db$cols))
  cat(sprintf("%-10s prec=%.3f recall=%.3f (TP=%d FP=%d FN=%d, truth=%d)\n",
              dbn, res$precision, res$recall, res$tp, res$fp, res$fn, res$n_truth))
  pooled[[dbn]] <- res
}
p <- evaluate_pooled(pooled)
cat(sprintf("POOLED     prec=%.3f recall=%.3f (TP=%d FP=%d FN=%d)\n",
            p$precision, p$recall, p$tp, p$fp, p$fn))
