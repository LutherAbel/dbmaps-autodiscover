# Auto-discovery of joinable column pairs and DBmaps-compatible metadata.
#
# Precision-first design, derived from measured baseline/iteration failures:
#   * A join TARGET must be a unique, id-named key.
#   * A real FK's child column NAME points at its parent. Two name links:
#       - column link  (album_id == album_id, original_language_id ~ language_id)
#         valid cross-table AND self-referential.
#       - table  link  (customerid ~ table customers) valid CROSS-table only;
#         allowing it within a table makes a table's own PK match its sibling
#         id columns (the self-table false positives).
#   * Value CONTAINMENT gates every match (robust where DBmaps Mode 2's strict
#     ==1.0 breaks on NULLs / orphan rows).
#   * Among value-contained, name-linked candidates, table-name affinity
#     (store_id -> table store, not staff) picks the right parent.
suppressMessages(library(data.table))

.empty_pairs <- function()
  data.table(table_from = character(), col_from = character(),
             table_to = character(), col_to = character())

.looks_like_id <- function(col) grepl("(^id$)|(_id$)|([a-z0-9]id$)", tolower(col))

# child column name matches the parent COLUMN (valid within or across tables)
.col_name_link <- function(cc, pc) cc == pc || (nchar(pc) >= 4 && endsWith(cc, pc))

# child column name matches the parent TABLE's entity (cross-table only)
.table_name_link <- function(cc, parent_table) {
  ent   <- sub("s$", "", tolower(parent_table))
  forms <- c(paste0(ent, "id"), paste0(ent, "_id"))
  (cc %in% forms) ||
    any(nchar(forms) >= 5 & vapply(forms, function(f) endsWith(cc, f), logical(1)))
}

.profile_table <- function(dt) {
  lapply(names(dt), function(cn) {
    v  <- dt[[cn]]; v <- v[!is.na(v)]
    cv <- as.character(v); uv <- unique(cv)
    list(col = cn, set = uv, n_distinct = length(uv),
         is_unique = length(uv) == length(cv) && length(cv) > 0)
  })
}

# Returns data.table(table_from, col_from, table_to, col_to) of FK->PK joins.
discover_joins <- function(db, tau = 0.95, min_card = 2) {
  tn   <- names(db$data)
  prof <- lapply(db$data, .profile_table); names(prof) <- tn

  pkeys <- list()
  for (t in tn) for (p in prof[[t]])
    if (p$is_unique && p$n_distinct >= min_card && .looks_like_id(p$col))
      pkeys[[length(pkeys) + 1]] <- list(table = t, col = p$col, set = p$set)
  if (length(pkeys) == 0) return(.empty_pairs())

  best <- list()  # one best parent per (child table, child col): FKs are functional
  for (ct in tn) for (cc in prof[[ct]]) {
    if (cc$n_distinct < 1) next
    cc_l <- tolower(cc$col)
    for (pk in pkeys) {
      same_tbl <- pk$table == ct
      if (same_tbl && pk$col == cc$col) next
      pc_l <- tolower(pk$col)
      link <- .col_name_link(cc_l, pc_l) || (!same_tbl && .table_name_link(cc_l, pk$table))
      if (!link) next
      inter <- length(intersect(cc$set, pk$set))
      exact <- identical(cc_l, pc_l)
      if (inter < (if (exact) 1 else 2)) next
      containment <- inter / cc$n_distinct
      if (containment < tau) next
      ent      <- sub("s$", "", tolower(pk$table))
      base     <- sub("_?id$", "", cc_l)
      affinity <- (base == ent) || (nchar(ent) >= 3 && startsWith(cc_l, ent))
      nsim     <- 0
      score    <- containment + 0.30 * affinity + 0.10 * nsim + 0.05 * exact
      key      <- paste0(ct, "", cc$col)
      if (is.null(best[[key]]) || score > best[[key]]$score)
        best[[key]] <- list(table_from = ct, col_from = cc$col,
                            table_to = pk$table, col_to = pk$col, score = score)
    }
  }
  if (length(best) == 0) return(.empty_pairs())
  rbindlist(lapply(best, function(b) data.table(
    table_from = b$table_from, col_from = b$col_from,
    table_to = b$table_to, col_to = b$col_to)))
}
