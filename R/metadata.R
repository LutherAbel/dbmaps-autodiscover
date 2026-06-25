# discover_metadata(): the single user command. Turns a database connection into
# a DBmaps-compatible MetadataRegistry with identifier_columns (and FK grouping
# links) auto-filled, so the user does not hand-write table_info() per table.
suppressMessages({library(data.table); library(DBmaps); library(DBI); library(RSQLite)})

# Choose the primary identifier column for a table: a unique, id-named column,
# preferring one named after the table (customers -> customerid / customer_id / id).
.pick_identifier <- function(tname, prof) {
  cands <- Filter(function(p) p$is_unique && p$n_distinct >= 1 && .looks_like_id(p$col), prof)
  if (length(cands) == 0) return(NA_character_)
  ent <- sub("s$", "", tolower(tname))
  score <- function(p) { c <- tolower(p$col)
    3 * (c == paste0(ent, "id")) + 3 * (c == paste0(ent, "_id")) +
    2 * (c == "id") + 1 * startsWith(c, ent) + 1e-9 * p$n_distinct }
  vapply(cands, function(p) p$col, character(1))[which.max(vapply(cands, score, numeric(1)))]
}

# Core: db structure -> list(registry, joins, identifiers)
discover_metadata_from_db <- function(db) {
  tn   <- names(db$data)
  prof <- lapply(db$data, .profile_table); names(prof) <- tn
  joins <- discover_joins(db)
  ids   <- setNames(vapply(tn, function(t) .pick_identifier(t, prof[[t]]), character(1)), tn)

  reg <- create_metadata_registry()
  for (t in tn) {
    idcol <- ids[[t]]
    if (is.na(idcol)) next
    fks <- joins[table_from == t, col_from]                 # FK cols where t is child
    grp <- unique(c(fks, idcol))                            # >=1 grouping var required
    aggs <- lapply(grp, function(g) list(
      AggregatedName = paste0("n_by_", g),
      AggregationFunction = "length", GroupingVariables = g))
    spec <- list(list(OutcomeName = idcol, ValueExpression = as.name(idcol),
                      AggregationMethods = aggs))
    reg <- add_table(reg, table_info(t, idcol, idcol, spec))
  }
  list(registry = reg, joins = joins, identifiers = ids)
}

# Load every base table of a SQLite database into the db structure.
.load_conn <- function(con) {
  tabs <- dbGetQuery(con,
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")$name
  data <- list()
  for (t in tabs) {
    df <- tryCatch(dbReadTable(con, t), error = function(e) NULL)
    if (!is.null(df) && ncol(df) > 0) data[[t]] <- as.data.table(df)
  }
  list(data = data,
       cols  = lapply(data, names),
       types = lapply(data, function(t) vapply(t, function(x) class(x)[1], character(1))))
}

# THE single user command. con: a DBI connection. Returns a MetadataRegistry.
discover_metadata <- function(con) {
  db <- .load_conn(con)
  discover_metadata_from_db(db)$registry
}
