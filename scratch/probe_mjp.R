# args: [1] = variant: full | noblob | nobig | blobonly
variant <- commandArgs(trailingOnly = TRUE)[1]
log <- file(paste0("scratch/mjp_", variant, ".log"), open = "wt")
p <- function(...) { writeLines(paste0(...), log); flush(log) }
p("start variant=", variant)
suppressMessages({library(DBI); library(RSQLite); library(data.table); library(DBmaps)})
con <- dbConnect(RSQLite::SQLite(), "data-raw/northwind.db")
tabs <- dbGetQuery(con, "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")$name
data_list <- list()
for (t in tabs) {
  df <- tryCatch(dbReadTable(con, t), error = function(e) NULL)
  if (!is.null(df) && ncol(df) > 0) data_list[[t]] <- as.data.table(df)
}
dbDisconnect(con)
p("loaded ", length(data_list), " tables")

drop_listcols <- function(dl) lapply(dl, function(dt) dt[, !vapply(dt, is.list, logical(1)), with = FALSE])
if (variant == "noblob")  { data_list <- drop_listcols(data_list); p("list-columns dropped") }
if (variant == "nobig")   { data_list[["Order Details"]] <- NULL; data_list[["Orders"]] <- NULL; p("big tables dropped") }
if (variant == "blobonly"){ data_list <- data_list[c("Categories","Employees","Shippers","Regions")]; p("kept blob tables + 2 small") }

meta <- table_info("Shippers", "ShipperID", "ShipperID",
  list(list(OutcomeName = "n", ValueExpression = quote(ShipperID),
    AggregationMethods = list(list(AggregatedName = "cnt",
      AggregationFunction = "length", GroupingVariables = "ShipperID")))))
p("metadata built; calling map_join_paths with data_list ...")
res <- tryCatch(suppressWarnings(map_join_paths(meta, data_list = data_list)),
                error = function(e) { p("R-ERROR: ", conditionMessage(e)); NULL })
p("returned: ", if (is.null(res)) "NULL (caught R error)" else paste0(nrow(res), " rows"))
p("DONE")
