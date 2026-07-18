# Auto-discovery of joinable column pairs. Logic mirrors the upstream PR file
# (DBmaps_fork/R/discover_metadata.R) so benchmark numbers describe the PR:
#   * parent keys: unique, id-named columns
#   * name gate: child name points at parent (equal / suffix >=4 / underscore
#     boundary for short keys / singularized table entity, cross-table only)
#   * value containment >= tau decides joinability; names never suffice alone
#   * alias_map: semantic-name escape hatch; opens the name gate only
#   * list-columns (BLOBs) are excluded at profiling time
suppressMessages(library(data.table))

.empty_pairs <- function()
  data.table(table_from = character(), col_from = character(),
             table_to = character(), col_to = character())

.looks_like_id <- function(col) grepl("(^id$)|(_id$)|([a-z0-9]id$)", tolower(col))

# Dictionary-free singularization: ies -> y, sibilant + es, plain s.
.singularize <- function(x) {
  x <- tolower(x)
  if (endsWith(x, "ies")) return(sub("ies$", "y", x))
  if (grepl("(ss|x|z|ch|sh)es$", x)) return(sub("es$", "", x))
  sub("s$", "", x)
}

.name_links_to_parent <- function(child_col, parent_col, parent_table, same_table) {
  cc <- tolower(child_col); pc <- tolower(parent_col)
  if (cc == pc) return(TRUE)
  if (nchar(pc) >= 4 && endsWith(cc, pc)) return(TRUE)          # bare suffix
  if (nchar(pc) >= 2 && endsWith(cc, paste0("_", pc))) return(TRUE)  # _uid form
  if (same_table) return(FALSE)
  ent <- .singularize(parent_table)
  forms <- c(paste0(ent, "id"), paste0(ent, "_id"))
  if (cc %in% forms) return(TRUE)
  any(nchar(forms) >= 5 & vapply(forms, function(f) endsWith(cc, f), logical(1)))
}

.profile_table <- function(dt) {
  lapply(names(dt), function(cn) {
    v <- dt[[cn]]
    if (is.list(v))
      return(list(col = cn, set = character(0), n_distinct = 0L, is_unique = FALSE))
    v <- v[!is.na(v)]
    uv <- unique(as.character(v))
    list(col = cn, set = uv, n_distinct = length(uv),
         is_unique = length(uv) == length(v) && length(v) > 0)
  })
}

# Returns data.table(table_from, col_from, table_to, col_to) of FK->PK joins.
discover_joins <- function(db, tau = 0.95, min_card = 2, alias_map = list()) {
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
    ai <- match(tolower(cc$col), tolower(names(alias_map)))   # case-insensitive
    eff_col <- if (!is.na(ai)) alias_map[[ai]] else cc$col
    cc_l <- tolower(eff_col)
    for (pk in pkeys) {
      same_tbl <- pk$table == ct
      if (same_tbl && pk$col == cc$col) next
      if (!.name_links_to_parent(eff_col, pk$col, pk$table, same_tbl)) next
      inter <- length(intersect(cc$set, pk$set))
      exact <- identical(cc_l, tolower(pk$col))
      if (inter < (if (exact) 1 else 2)) next
      containment <- inter / cc$n_distinct
      if (containment < tau) next
      ent      <- .singularize(pk$table)
      base     <- sub("_?id$", "", cc_l)
      affinity <- (base == ent) || (nchar(ent) >= 3 && startsWith(cc_l, ent))
      score    <- containment + 0.30 * affinity + 0.05 * exact
      key      <- paste(ct, cc$col, sep = "\r")
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
