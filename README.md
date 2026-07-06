# DBmaps Auto Metadata Discovery

A small, pure-R module that **auto-generates a [DBmaps](https://cran.r-project.org/package=DBmaps)-compatible
metadata registry** from a database, so the per-table keys can be discovered instead
of hand-written. One user command: `discover_metadata(con)`.

## Why

DBmaps (CRAN) is metadata-driven: `map_join_paths()` needs the user to declare each
table's keys first via `table_info()`. Its optional data-driven mode auto-detects joins,
but only by strict 100% value containment + exact type, which is brittle. This module
fills that gap: robust auto-detection that emits a registry, so the metadata is
generated, not typed.

## Results (measured, not estimated)

Ground truth = declared FOREIGN KEYs of three standard sample databases (Chinook,
Sakila, Northwind): 40 tables, 46 FK pairs. All numbers come from `evaluate()`.

| method | precision | recall |
|--------|-----------|--------|
| baseline: exact column-name match | 0.182 | 0.870 |
| baseline: DBmaps' own data-driven mode | 0.066 | 0.652 |
| **this module** | **1.000** | **0.848** |

- Manual effort reduced: **94.1%** of tables get `identifier_columns` auto-filled correctly.
- The registry is consumed by `map_join_paths()` unchanged; Mode 1 recovers 32/46 FKs from
  the auto-registry alone.
- Scalability (rows/table=100): 100 tables in **1.2s / 55 MB**; 1000 tables in 140s / 103 MB.

## Quick start

```r
# 1. fetch the ground-truth databases (one-time)
Rscript data-raw/fetch_data.R

# 2. reproduce everything (run from the repo root)
Rscript tests/run_all.R        # TDD specs
Rscript run_eval.R             # accuracy vs baselines
Rscript verify_registry.R      # effort reduction + map_join_paths consumption
Rscript bench/scalability.R    # 10 / 100 / 1000 tables

# 3. use it
library(DBI); library(RSQLite)
for (f in list.files("R", full.names = TRUE)) source(f)
con <- dbConnect(RSQLite::SQLite(), "data-raw/Chinook_Sqlite.sqlite")
registry <- discover_metadata(con)        # -> a DBmaps MetadataRegistry
```

Dependencies: `data.table`, `stringdist`, `DBI`, `RSQLite`, `DBmaps`. No ML runtime.

## How it works

1. Profile every column (distinct value set, cardinality, uniqueness).
2. **Parent keys** = unique, id-named columns.
3. A pair is a join iff the child name points at the parent (equal / `endsWith` /
   entity form) **and** child values are >= `tau` contained in the parent key. Names
   disambiguate *which* parent (`store_id` -> table `store`, not `staff`); **values decide**.

## Limitations (honest)

- **Precision leans on naming convention.** Value containment alone is ambiguous among
  surrogate keys (any `1..k` sits inside any larger `1..m`); the name link is what makes
  precision high. On cryptically-named schemas precision degrades toward the value-only
  baseline. This is a convention-following-schema tool.
- **Misses semantic FK names** (`reportsto`, `shipvia`, `supportrepid`) and columns with
  no value evidence (all-NULL columns, empty tables). 5 of 7 misses are semantic.
- **The candidate loop is O(tables^2)** (1000 tables = 140s; memory flat). A name-index
  hash-join would make it near-linear.

See [`DESIGN.md`](DESIGN.md) for the full design note and critique, and
[`eval_log.md`](eval_log.md) for the iteration-by-iteration measured history.

## Upstream finding

`map_join_paths(registry, data_list = ...)` fails with **`Error: Unsupported type raw`**
on any database containing BLOB columns (e.g. Northwind's `Employees$Photo`): DBI/RSQLite
returns BLOBs as `blob` class columns (vctrs-based), and `unique()`/`anyDuplicated()` in
the scanner dispatch to vctrs methods that do not support the raw type. This makes the
data-driven mode unusable on such databases. A self-contained reproducer is in
[`scratch/reproducer.R`](scratch/reproducer.R); a type guard (`is.list(col) -> skip`)
fixes it. This module's metadata path is unaffected.

(An earlier note here reported a segfault; that turned out to be an artifact of our own
R invocation method, not DBmaps — the deterministic upstream failure is the error above.)

## Status

A proposed contribution plus its evaluation harness. Not yet merged into DBmaps.

## License

MIT. Built on top of the DBmaps package by Akshat Maurya and David Shilane.
