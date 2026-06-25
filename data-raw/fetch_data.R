# Fetch the ground-truth databases used for evaluation. Run once from the repo root.
# These are standard sample databases that carry authoritative FOREIGN KEY constraints,
# which serve as the labeled join ground truth.
dir <- "data-raw"
dir.create(dir, showWarnings = FALSE)
urls <- c(
  Chinook_Sqlite.sqlite =
    "https://github.com/lerocha/chinook-database/raw/master/ChinookDatabase/DataSources/Chinook_Sqlite.sqlite",
  sakila.db =
    "https://github.com/bradleygrant/sakila-sqlite3/raw/main/sakila_master.db",
  northwind.db =
    "https://github.com/jpwhite3/northwind-SQLite3/raw/main/dist/northwind.db"
)
for (nm in names(urls)) {
  dest <- file.path(dir, nm)
  cat("downloading", nm, "...\n")
  ok <- tryCatch({ download.file(urls[[nm]], dest, mode = "wb", quiet = TRUE); TRUE },
                 error = function(e) { cat("  FAILED:", conditionMessage(e), "\n"); FALSE })
  if (ok) cat(sprintf("  saved %s (%.0f KB)\n", dest, file.info(dest)$size / 1024))
}
