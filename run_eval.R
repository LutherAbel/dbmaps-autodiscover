# Full evaluation: baselines + the auto-discoverer, measured on real DBs.
root <- Sys.getenv("DBMAPS_ROOT", ".")
for (f in c("groundtruth.R","evaluate.R","baselines.R","discover.R"))
  source(file.path(root, "R", f))

dbs <- list(
  chinook   = file.path(root, "data-raw", "Chinook_Sqlite.sqlite"),
  sakila    = file.path(root, "data-raw", "sakila.db"),
  northwind = file.path(root, "data-raw", "northwind.db")
)

methods <- list(
  exact_name   = function(db) discover_exact_name(db),
  dbmaps_mode2 = function(db) discover_dbmaps_mode2(db),
  autodiscover = function(db) discover_joins(db)
)

cat(sprintf("%-10s %-13s %6s %6s %6s %6s %5s %5s %5s\n",
            "db","method","prec","recall","fpr","fnr","TP","FP","FN"))
cat(strrep("-", 78), "\n")

pooled <- setNames(lapply(names(methods), function(x) list()), names(methods))
loaded <- lapply(dbs, load_sqlite_db)

for (dbn in names(dbs)) {
  db <- loaded[[dbn]]; uni <- count_universe(db$cols)
  for (mn in names(methods)) {
    res <- evaluate(methods[[mn]](db), db$truth, uni)
    pooled[[mn]][[dbn]] <- res
    cat(sprintf("%-10s %-13s %6.3f %6.3f %6.4f %6.3f %5d %5d %5d\n",
                dbn, mn, res$precision, res$recall, res$fpr, res$fnr,
                res$tp, res$fp, res$fn))
  }
}
cat(strrep("-", 78), "\n")
cat("POOLED (micro-avg across all 3 databases):\n")
for (mn in names(methods)) {
  p <- evaluate_pooled(pooled[[mn]])
  cat(sprintf("  %-13s precision=%.3f  recall=%.3f  (TP=%d FP=%d FN=%d, pred=%d, truth=%d)\n",
              mn, p$precision, p$recall, p$tp, p$fp, p$fn, p$n_pred, p$n_truth))
}
