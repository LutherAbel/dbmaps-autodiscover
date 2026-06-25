# Auto Metadata Discovery for DBmaps — Design Note

**What it is.** A small, pure-R module that auto-generates a DBmaps-compatible
`MetadataRegistry` from a database connection, filling in the per-table
`identifier_columns` (and foreign-key grouping links) that a user otherwise types
by hand with `table_info()`. One user command: `discover_metadata(con)`.

**Why.** DBmaps (CRAN) is metadata-driven: `map_join_paths()` Mode 1 needs the user
to declare each table's keys first. Its optional Mode 2 (pass the data) auto-detects
joins but by *strict 100% value containment + exact type*, which is brittle (and, see
below, crashes on Northwind). This module fills the gap the package left open:
robust auto-detection that emits a registry, so the metadata is generated, not typed.

## How it works
1. Reflect tables; profile each column (distinct value set, cardinality, uniqueness).
2. **Parent keys** = unique, id-named columns (`id`, `_id`, `<entity>Id`).
3. A column pair is a join iff **(a)** the child name links to the parent — equal,
   `endsWith` the parent column (`original_language_id`~`language_id`), or matches the
   parent table's entity (`customerid`~`customers`); **and (b)** child values are
   ≥`tau` contained in the parent key. Name disambiguates *which* parent (`store_id`→
   table `store`, not `staff`); **values decide** joinability.
4. Self-references allowed (link via parent *column* only, never parent *table* —
   that distinction removes the self-table false positives).
5. Emit one `table_info()` row set per table: `identifier_columns` = detected PK,
   grouping variables = discovered FK columns. Assemble with `add_table()`.

## Measured results (from `evaluate()` / probes — no self-assigned numbers)
Ground truth = declared FKs of Chinook + Sakila + Northwind (40 tables, 46 FK pairs).

| method | precision | recall |
|--------|-----------|--------|
| baseline: exact column-name | 0.182 | 0.870 |
| baseline: DBmaps Mode 2 (its own) | 0.066 | 0.652 |
| **autodiscover (this module)** | **1.000** | **0.848** |

- Effort reduction (identifier_columns auto-filled correctly): **32/34 = 94.1%**.
- Registry consumed by `map_join_paths()` unchanged: **PASS**; Mode 1 recovers 32/46
  true FKs from the auto-registry alone (no data needed).
- Scalability (rows/table=100): 10 tbl 0.06s · 100 tbl **1.22s / 55 MB** · 1000 tbl 140s / 103 MB.

**Success criteria:** prec>0.90 ✓ · recall>0.80 ✓ · effort>70% ✓ · 100+ tables in budget ✓ ·
passes into `map_join_paths()` ✓ · one command ✓ · deps in budget ✓
(`data.table`, `stringdist`, `DBI`, `RSQLite` — no ML runtime).

## Mandatory critique (assume it's flawed)
1. **Weakest component:** the name-link gate. It is the whole basis of precision, so it
   is also the recall ceiling — any FK whose column name does not echo its parent is
   invisible.
2. **Most likely failure mode:** semantic FK names. Ground-truth cases that expose it:
   `customer.supportrepid→employee.employeeid`, `orders.shipvia→shippers.shipperid`,
   `employees.reportsto→employees.employeeid`. All real, all missed (5 of 7 FNs).
3. **Most likely maintainer objection:** "value containment reads every column into
   memory and is O(tables²) in the candidate loop" (measured: 140s at 1000 tables).
4. **Largest technical risk:** containment on full columns does not scale to big rows;
   needs MinHash/LSH sketches before production-size data.
5. **Largest product risk:** FK constraints are an *imperfect* oracle — the module may
   find real, useful joins that are not declared FKs and be scored as false positives,
   understating its true value.

## Root causes + the fixes not yet taken
- **Semantic misses (recall ceiling).** Cause: pure lexical name link. Fix: optional,
  non-default synonym table (`rep→employee`, `shipvia→shipper`) — kept optional to stay
  inside the dependency budget; a transformer matcher belongs only as an opt-in plugin.
- **O(tables²) candidate loop (1000-tbl = 140s).** Cause: every (child col × parent key)
  pair is name-checked. Fix: index parent keys by their expected child-name forms and
  hash-join, turning the scan ~linear. Memory is already flat (103 MB at 1000 tables).
- **Containment cost on large rows.** Fix: MinHash signatures + LSH banding to estimate
  containment without materializing full value sets.

## Upstream finding (worth reporting to DBmaps)
`map_join_paths(registry, data_list=northwind)` **segfaults** (R exit 139) — its Mode 2
discovery is not robust to certain column types/data. This module's Mode-1 registry path
is unaffected. Reproducer: load `data-raw/northwind.db`, build any registry, call with
`data_list`.

## Files
- `R/discover.R` — `discover_joins()` (join detection)
- `R/metadata.R` — `discover_metadata()` (single command → registry)
- `R/evaluate.R`, `R/groundtruth.R`, `R/baselines.R` — measurement floor
- `tests/test_discover*.R` — TDD specs (run `tests/run_all.R`)
- `run_eval.R` (accuracy), `verify_registry.R` (effort/consumption), `bench/scalability.R`
- `eval_log.md` — full measured history
