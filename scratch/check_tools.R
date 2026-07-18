ip <- rownames(installed.packages())
for (p in c("roxygen2", "testthat", "devtools", "knitr", "rmarkdown"))
  cat(p, ifelse(p %in% ip, "INSTALLED", "---missing---"), "\n")
