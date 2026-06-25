# Ground-truth loading for the measurement floor.
# Labels come from the databases' own declared FOREIGN KEY constraints
# (PRAGMA foreign_key_list), which are authoritative join pairs.
suppressMessages({library(DBI); library(RSQLite); library(data.table)})

# Load a SQLite database into the structure every discoverer consumes:
#   data  : named list of data.tables (one per base table)
#   cols  : named list of column-name vectors
#   types : named list of column R-class vectors
#   truth : data.table(table_from, col_from, table_to, col_to) of declared FKs
load_sqlite_db <- function(path) {
  con <- dbConnect(RSQLite::SQLite(), path)
  on.exit(dbDisconnect(con))

  tabs <- dbGetQuery(con,
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")$name

  data <- list(); cols <- list(); types <- list()
  for (t in tabs) {
    df <- tryCatch(dbReadTable(con, t), error = function(e) NULL)
    if (is.null(df) || ncol(df) == 0) next
    dt <- as.data.table(df)
    data[[t]]  <- dt
    cols[[t]]  <- names(dt)
    types[[t]] <- vapply(dt, function(x) class(x)[1], character(1))
  }

  truth <- list()
  for (t in names(data)) {
    fk <- tryCatch(dbGetQuery(con, sprintf("PRAGMA foreign_key_list('%s')", t)),
                   error = function(e) NULL)
    if (is.null(fk) || nrow(fk) == 0) next
    for (i in seq_len(nrow(fk))) {
      from_col <- fk$from[i]; to_tab <- fk$table[i]; to_col <- fk$to[i]
      if (is.na(to_col)) {                       # FK to target's PK, unnamed
        pk <- tryCatch(dbGetQuery(con, sprintf("PRAGMA table_info('%s')", to_tab)),
                       error = function(e) NULL)
        if (!is.null(pk)) { pkc <- pk$name[pk$pk > 0]; if (length(pkc)) to_col <- pkc[1] }
      }
      if (is.na(to_col) || is.null(data[[to_tab]])) next
      truth[[length(truth) + 1]] <- data.table(
        table_from = t, col_from = from_col, table_to = to_tab, col_to = to_col)
    }
  }
  truth_dt <- if (length(truth)) rbindlist(truth) else
    data.table(table_from = character(), col_from = character(),
               table_to = character(), col_to = character())

  list(data = data, cols = cols, types = types, truth = truth_dt)
}
