# RED (Iteration 2): the surrogate-key ambiguity + self-reference cases.
root <- Sys.getenv("DBMAPS_ROOT", ".")
source(file.path(root, "R", "discover.R"))
suppressMessages(library(data.table))

mk_db <- function(tabs) list(
  data = tabs, cols = lapply(tabs, names),
  types = lapply(tabs, function(t) vapply(t, function(x) class(x)[1], character(1))))

# album_id (1:5) is value-contained in track_id (1:20) -> SURROGATE COINCIDENCE.
# The real FK is track.album_id -> album.album_id (child named after parent).
album <- data.table(album_id = 1:5, title = letters[1:5])
track <- data.table(track_id = 1:20, album_id = rep(1:5, 4), name = letters[1:20])
# self-referential FK: category.parent_category_id -> category.category_id
category <- data.table(category_id = 1:6,
                       parent_category_id = c(NA, 1, 1, 2, 2, 3),
                       label = letters[1:6])
db <- mk_db(list(album = album, track = track, category = category))

pred <- discover_joins(db)
cat("predicted pairs:\n"); print(pred)
has <- function(tf,cf,tt,ct) any(
  (pred$table_from==tf & pred$col_from==cf & pred$table_to==tt & pred$col_to==ct) |
  (pred$table_from==tt & pred$col_from==ct & pred$table_to==tf & pred$col_to==cf))

stopifnot("real FK track.album_id->album.album_id missing" =
            has("track","album_id","album","album_id"))
stopifnot("self-ref category.parent_category_id->category.category_id missing" =
            has("category","parent_category_id","category","category_id"))
stopifnot("surrogate coincidence album.album_id<->track.track_id wrongly predicted" =
            !has("album","album_id","track","track_id"))
cat("TEST PASSED: test_discover2\n")
