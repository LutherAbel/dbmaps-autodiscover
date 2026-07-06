log <- file("scratch/probe.log", open = "wt")
p <- function(...) { writeLines(paste0(...), log); flush(log) }
p("script started")
suppressMessages({library(DBI); library(RSQLite)})
p("libs loaded")
con <- dbConnect(RSQLite::SQLite(), "data-raw/northwind.db")
p("connected")
tabs <- dbGetQuery(con, "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")$name
p("tables: ", paste(tabs, collapse=", "))
for (t in tabs) {
  p("reading: ", t)
  df <- tryCatch(dbReadTable(con, t), error = function(e) { p("  R-error: ", conditionMessage(e)); NULL })
  if (!is.null(df)) {
    lc <- names(df)[vapply(df, is.list, logical(1))]
    p("  ok rows=", nrow(df), if (length(lc)) paste0("  LIST-COLS: ", paste(lc, collapse=",")) else "")
  }
}
p("ALL TABLES READ OK")
