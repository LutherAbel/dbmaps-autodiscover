# The single source of all accuracy numbers. No discoverer may self-score;
# every reported metric comes from evaluate().
suppressMessages(library(data.table))

# Canonical, order-independent key for an (undirected) joinable column pair.
canon_pair <- function(ta, ca, tb, cb) {
  a <- paste0(tolower(ta), ".", tolower(ca))
  b <- paste0(tolower(tb), ".", tolower(cb))
  paste(sort(c(a, b)), collapse = "|")
}

pairs_to_keys <- function(dt) {
  if (is.null(dt) || nrow(dt) == 0) return(character(0))
  unique(vapply(seq_len(nrow(dt)), function(i)
    canon_pair(dt$table_from[i], dt$col_from[i], dt$table_to[i], dt$col_to[i]),
    character(1)))
}

# Negative universe = all cross-table unordered column pairs. Used for FPR.
count_universe <- function(cols) {
  tn <- names(cols); total <- 0
  for (i in seq_along(tn)) for (j in seq_along(tn)) if (i < j)
    total <- total + length(cols[[tn[i]]]) * length(cols[[tn[j]]])
  total
}

# predicted/truth: data.table(table_from, col_from, table_to, col_to)
evaluate <- function(pred_dt, truth_dt, universe_size) {
  P <- pairs_to_keys(truth_dt)
  D <- pairs_to_keys(pred_dt)
  tp <- length(intersect(D, P))
  fp <- length(setdiff(D, P))
  fn <- length(setdiff(P, D))
  neg <- max(universe_size - length(P), 1)
  list(
    precision = if (length(D)) tp / length(D) else NA_real_,
    recall    = if (length(P)) tp / length(P) else NA_real_,
    fpr       = fp / neg,
    fnr       = if (length(P)) fn / length(P) else NA_real_,
    tp = tp, fp = fp, fn = fn, n_pred = length(D), n_truth = length(P)
  )
}

# Pool metrics across several databases (micro-average over pairs).
evaluate_pooled <- function(results) {
  tp <- sum(vapply(results, `[[`, numeric(1), "tp"))
  fp <- sum(vapply(results, `[[`, numeric(1), "fp"))
  fn <- sum(vapply(results, `[[`, numeric(1), "fn"))
  np <- sum(vapply(results, `[[`, numeric(1), "n_pred"))
  nt <- sum(vapply(results, `[[`, numeric(1), "n_truth"))
  list(
    precision = if (np) tp / np else NA_real_,
    recall    = if (nt) tp / nt else NA_real_,
    tp = tp, fp = fp, fn = fn, n_pred = np, n_truth = nt
  )
}
