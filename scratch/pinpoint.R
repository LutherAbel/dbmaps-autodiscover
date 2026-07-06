suppressMessages({library(DBI); library(RSQLite); library(data.table)})
con <- dbConnect(RSQLite::SQLite(), "data-raw/northwind.db")
emp <- as.data.table(dbReadTable(con, "Employees"))
dbDisconnect(con)
ph <- emp$Photo
cat("class of Photo col:", paste(class(ph), collapse=","), "\n")
cat("class of element:  ", paste(class(ph[[1]]), collapse=","), "\n")
try_op <- function(label, expr) {
  r <- tryCatch({ force(expr); "OK" }, error = function(e) paste("ERROR:", conditionMessage(e)))
  cat(sprintf("%-28s %s\n", label, r))
}
try_op("anyDuplicated(Photo)",  anyDuplicated(ph))
try_op("unique(Photo)",         unique(ph))
try_op("Photo %in% Photo",      ph %in% ph)
try_op("unlist-1 %in% Photo",   ph[[1]] %in% ph)
# and the plain-list versions for contrast
pl <- unclass(ph)
try_op("anyDuplicated(unclass)", anyDuplicated(pl))
try_op("unique(unclass)",        unique(pl))
try_op("unclass %in% unclass",   pl %in% pl)
