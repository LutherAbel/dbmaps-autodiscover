# Criteria 3, 5, 6: registry emission, effort reduction, map_join_paths consumption.
# NOTE: we exercise map_join_paths(registry) -- the call that consumes OUR registry
# (Mode 1). We deliberately do NOT call DBmaps' Mode 2 (data_list) discovery here:
# it segfaults on Northwind (see DESIGN.md "upstream findings") and is not our output.
root <- Sys.getenv("DBMAPS_ROOT", ".")
for (f in c("groundtruth.R","evaluate.R","discover.R","metadata.R"))
  source(file.path(root, "R", f))
suppressMessages({library(DBI); library(RSQLite); library(DBmaps)})

dbs <- list(chinook="Chinook_Sqlite.sqlite", sakila="sakila.db", northwind="northwind.db")

true_pks <- function(path) {
  con <- dbConnect(RSQLite::SQLite(), path); on.exit(dbDisconnect(con))
  tabs <- dbGetQuery(con,"SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")$name
  out <- list()
  for (t in tabs) {
    ti <- tryCatch(dbGetQuery(con, sprintf("PRAGMA table_info('%s')", t)), error=function(e) NULL)
    if (!is.null(ti)) { pk <- ti$name[ti$pk>0]; if (length(pk)==1) out[[t]] <- pk }
  }
  out
}

tot_tab <- 0; tot_pk_ok <- 0; consume_ok <- TRUE; m1_tp <- 0; m1_truth <- 0
for (dbn in names(dbs)) {
  path <- file.path(root, "data-raw", dbs[[dbn]])
  db <- load_sqlite_db(path); md <- discover_metadata_from_db(db); tpk <- true_pks(path)

  tabs_with_pk <- intersect(names(tpk), names(db$data))
  ok <- sum(vapply(tabs_with_pk, function(t)
    !is.na(md$identifiers[[t]]) && tolower(md$identifiers[[t]]) == tolower(tpk[[t]]), logical(1)))
  tot_tab <- tot_tab + length(tabs_with_pk); tot_pk_ok <- tot_pk_ok + ok

  m1 <- tryCatch(suppressWarnings(map_join_paths(md$registry)),
                 error=function(e){consume_ok<<-FALSE; NULL})
  if (is.null(m1)) consume_ok <- FALSE
  if (!is.null(m1) && nrow(m1)>0) {
    pred <- data.table(table_from=m1$table_from,
                       col_from=vapply(m1$key_from,function(x)paste(x,collapse=","),character(1)),
                       table_to=m1$table_to,
                       col_to=vapply(m1$key_to,function(x)paste(x,collapse=","),character(1)))
    m1_tp <- m1_tp + evaluate(pred, db$truth, count_universe(db$cols))$tp
  }
  m1_truth <- m1_truth + nrow(db$truth)
  cat(sprintf("%-10s tables=%2d  PK auto-filled=%2d/%2d  map_join_paths(registry)=%s rows\n",
              dbn, length(db$data), ok, length(tabs_with_pk),
              if(is.null(m1)) "ERROR" else nrow(m1)))
}
cat(strrep("-",78),"\n")
cat(sprintf("EFFORT REDUCTION (identifier_columns auto-filled): %d/%d = %.1f%%  [target >70%%]\n",
            tot_pk_ok, tot_tab, 100*tot_pk_ok/tot_tab))
cat(sprintf("CRITERION 5 (registry consumed by map_join_paths unchanged): %s\n",
            if (consume_ok) "PASS" else "FAIL"))
cat(sprintf("Pure-metadata (Mode 1) recovered %d/%d true FKs from the auto-registry alone.\n",
            m1_tp, m1_truth))
