# Criterion 4: measured scalability at 10 / 100 / 1000 tables. Not imagined.
root <- Sys.getenv("DBMAPS_ROOT", ".")
source(file.path(root, "R", "discover.R"))
suppressMessages(library(data.table))

# Synthetic schema: each table has an id PK, a few attribute columns, and a few
# FK columns named after an earlier table's id (so they are discoverable).
gen_schema <- function(n_tables, rows = 100, n_attr = 3, fk_per = 2) {
  data <- list()
  for (i in seq_len(n_tables)) {
    idcol <- paste0("t", i, "_id")
    dt <- data.table(.id = seq_len(rows)); setnames(dt, ".id", idcol)
    for (a in seq_len(n_attr)) dt[[paste0("t", i, "_attr", a)]] <- sample(letters, rows, TRUE)
    if (i > 1) for (k in seq_len(min(fk_per, i - 1))) {
      tgt <- ((i * 7 + k) %% (i - 1)) + 1
      dt[[paste0("t", tgt, "_id")]] <- sample.int(rows, rows, replace = TRUE)
    }
    data[[paste0("t", i)]] <- dt
  }
  list(data = data, cols = lapply(data, names),
       types = lapply(data, function(t) vapply(t, function(x) class(x)[1], character(1))))
}

probe <- function(n) {
  db <- gen_schema(n)
  ncols <- sum(lengths(db$cols))
  invisible(gc(reset = TRUE))
  el <- system.time(res <- discover_joins(db))[["elapsed"]]
  peak_mb <- sum(gc()[, 6])                     # column 6 = max used (Mb)
  cat(sprintf("tables=%5d  cols=%6d  time=%7.2fs  joins_found=%5d  peak_mem=%7.1f Mb\n",
              n, ncols, el, nrow(res), peak_mb))
}

cat("Scalability probe (rows/table=100, ~6 cols/table):\n")
for (n in c(10, 100, 1000)) probe(n)
