# Baselines the real module must beat. Every later number is a delta over these.
suppressMessages({library(data.table); library(DBmaps)})

empty_pairs <- function()
  data.table(table_from = character(), col_from = character(),
             table_to = character(), col_to = character())

# Baseline A: the dumbest reasonable discoverer -- join any two columns
# across tables that share an identical name (optionally same type).
discover_exact_name <- function(db, require_type = TRUE) {
  cols <- db$cols; types <- db$types; tn <- names(cols)
  out <- list()
  for (i in seq_along(tn)) for (j in seq_along(tn)) if (i < j) {
    ci <- cols[[tn[i]]]; cj <- cols[[tn[j]]]
    common <- intersect(tolower(ci), tolower(cj))
    for (cc in common) {
      ai <- ci[tolower(ci) == cc][1]; aj <- cj[tolower(cj) == cc][1]
      if (require_type && types[[tn[i]]][ai] != types[[tn[j]]][aj]) next
      out[[length(out) + 1]] <- data.table(
        table_from = tn[i], col_from = ai, table_to = tn[j], col_to = aj)
    }
  }
  if (length(out)) rbindlist(out) else empty_pairs()
}

# Baseline B: DBmaps' OWN data-driven discoverer (map_join_paths Mode 2).
# Strict 100% value containment + exact type. This is the real bar to beat.
discover_dbmaps_mode2 <- function(db) {
  data_list <- db$data
  t1 <- names(data_list)[1]; c1 <- db$cols[[t1]][1]
  g  <- db$cols[[t1]][min(2, length(db$cols[[t1]]))]
  # Single-table dummy metadata => Mode 1 contributes nothing; only Mode 2 fires.
  dummy <- table_info(t1, c1, c1, list(list(
    OutcomeName = "o", ValueExpression = as.name(g),
    AggregationMethods = list(list(
      AggregatedName = "a", AggregationFunction = "length", GroupingVariables = c1)))))
  jm <- tryCatch(suppressWarnings(map_join_paths(dummy, data_list = data_list)),
                 error = function(e) NULL)
  if (is.null(jm) || nrow(jm) == 0) return(empty_pairs())
  data.table(
    table_from = jm$table_from,
    col_from   = vapply(jm$key_from, function(x) paste(x, collapse = ","), character(1)),
    table_to   = jm$table_to,
    col_to     = vapply(jm$key_to,   function(x) paste(x, collapse = ","), character(1)))
}
