# Print the actual FP / FN column pairs for autodiscover, per DB. Evidence for root cause.
root <- Sys.getenv("DBMAPS_ROOT", ".")
for (f in c("groundtruth.R","evaluate.R","discover.R")) source(file.path(root,"R",f))

dbs <- list(chinook="Chinook_Sqlite.sqlite", sakila="sakila.db", northwind="northwind.db")
for (dbn in names(dbs)) {
  db <- load_sqlite_db(file.path(root,"data-raw",dbs[[dbn]]))
  pred <- discover_joins(db)
  P <- pairs_to_keys(db$truth); D <- pairs_to_keys(pred)
  fp <- setdiff(D, P); fn <- setdiff(P, D)
  cat("\n=====", dbn, "=====  (TP=", length(intersect(D,P)), " FP=", length(fp), " FN=", length(fn), ")\n")
  cat("-- FALSE POSITIVES (predicted, not a declared FK):\n")
  if (length(fp)) cat(paste0("   ", fp), sep="\n") else cat("   (none)\n")
  cat("\n-- FALSE NEGATIVES (declared FK, missed):\n")
  if (length(fn)) cat(paste0("   ", fn), sep="\n") else cat("   (none)\n")
}
