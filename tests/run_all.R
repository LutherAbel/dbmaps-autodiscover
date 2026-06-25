# Run all TDD specs; non-zero exit if any fails.
root <- Sys.getenv("DBMAPS_ROOT", ".")
tests <- c("test_discover.R", "test_discover2.R", "test_discover3.R")
fail <- 0
for (t in tests) {
  ok <- tryCatch({ sys.source(file.path(root, "tests", t), envir = new.env()); TRUE },
                 error = function(e) { cat("FAIL", t, ":", conditionMessage(e), "\n"); FALSE })
  if (!ok) fail <- fail + 1
}
cat(sprintf("\n%d/%d test files passed\n", length(tests) - fail, length(tests)))
if (fail > 0) quit(status = 1)
