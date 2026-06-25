# Iteration 0: establish the measurement floor on real ground-truth databases.
root <- Sys.getenv("DBMAPS_ROOT", ".")
source(file.path(root, "R", "groundtruth.R"))
source(file.path(root, "R", "evaluate.R"))
source(file.path(root, "R", "baselines.R"))

dbs <- list(
  chinook   = file.path(root, "data-raw", "Chinook_Sqlite.sqlite"),
  sakila    = file.path(root, "data-raw", "sakila.db"),
  northwind = file.path(root, "data-raw", "northwind.db")
)

methods <- list(
  exact_name   = discover_exact_name,
  dbmaps_mode2 = discover_dbmaps_mode2
)

cat(sprintf("%-10s %-13s %6s %6s %6s %6s %5s %5s %5s\n",
            "db", "method", "prec", "recall", "fpr", "fnr", "TP", "FP", "FN"))
cat(strrep("-", 78), "\n")

pooled <- list()
for (mn in names(methods)) pooled[[mn]] <- list()

for (dbn in names(dbs)) {
  db <- load_sqlite_db(dbs[[dbn]])
  uni <- count_universe(db$cols)
  for (mn in names(methods)) {
    pred <- methods[[mn]](db)
    res  <- evaluate(pred, db$truth, uni)
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
