---
name: optimize-postgres
description: >
  PostgreSQL performance: find slow queries, read plans, and tune indexes,
  writes, and server config. MUST be invoked when a Postgres query is slow, a
  query needs an index, EXPLAIN shows a Seq Scan on a large table, inserts or
  bulk loads are slow, autovacuum/bloat is suspected, or you're choosing index
  types or server settings. Covers pg_stat_statements, EXPLAIN (ANALYZE,
  BUFFERS), index types (btree/partial/expression/covering, GIN, GiST, BRIN),
  ANALYZE and autovacuum, COPY and bulk-load tuning, and the shared_buffers /
  work_mem / effective_cache_size baseline.
when_to_use: >
  Use for "this Postgres query is slow", "what index should I add", "why is
  this a seq scan", "EXPLAIN ANALYZE", "index JSONB", "GIN vs BRIN", "slow
  inserts", "bulk load / COPY", "table bloat", "autovacuum tuning",
  "pg_stat_statements", "which postgresql.conf settings", or when a migration
  adds an index and you want to confirm it's right. For SQLite see
  `optimize-sqlite`; for schema conventions see the `sql` rule.
---

# Optimizing PostgreSQL

Plan node names and behaviors below are verified on PostgreSQL 18.4.

## The Loop

1. **Find the query that matters** with `pg_stat_statements`, ranked by
   *cumulative* time, not per-call time (below). A 5 ms query run 100k times
   outweighs a 30 s report run once.
2. **Read its plan** with `EXPLAIN (ANALYZE, BUFFERS)`. Find the lowest node
   where estimated rows diverge from actual rows by ~10x or more: a bad
   estimate there is usually the root cause, and the slow node above is just a
   consequence.
3. **Fix the cause** (missing/expression index, stale stats, a query rewrite),
   not the symptom.
4. **Re-check the plan and the stats.** A change that doesn't move the plan or
   the `pg_stat_statements` totals didn't help. Reset stats between runs with
   `SELECT pg_stat_statements_reset();`.

## Finding the slow query: pg_stat_statements

The standard entry point. It's bundled but needs enabling:
add `pg_stat_statements` to `shared_preload_libraries` in `postgresql.conf`,
restart, then `CREATE EXTENSION pg_stat_statements;`.

Rank by total time, since a cheap-but-frequent query can dominate load:

```sql
SELECT calls,
       round(total_exec_time::numeric, 1) AS total_ms,
       round(mean_exec_time::numeric, 2)  AS mean_ms,
       round(stddev_exec_time::numeric, 2) AS stddev_ms,
       query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

High `stddev_ms` relative to `mean_ms` flags a query that is sometimes fast and
sometimes slow: lock contention, autovacuum interference, or plan instability.

## Reading EXPLAIN (ANALYZE, BUFFERS)

Run `EXPLAIN (ANALYZE, BUFFERS) <query>`. `ANALYZE` executes the query, so wrap
writes in a transaction you `ROLLBACK`. Costs are not milliseconds (cost `1.0` =
reading one 8 kB page sequentially); the number that matters is `Execution
Time`. What to read:

- **Estimated vs actual rows.** The highest-value signal. A node showing
  `(rows=100)` planned but `actual rows=100000` means the planner is working
  from a wrong estimate and likely chose the wrong scan or join. Fix the
  estimate (ANALYZE, or raise statistics targets) before adding indexes.
- **`Rows Removed by Filter`.** A large value on a `Seq Scan` means Postgres
  read many rows to discard most, the classic missing-index signal.
- **`Buffers: shared hit=… read=…`.** `hit` is the cache; `read` came from
  disk (or OS cache). High `read` on a large-table scan returning few rows is a
  prime index candidate.
- **Scan types**, cheapest to most wasteful for a selective query:
  `Index Only Scan` (served entirely from the index) > `Index Scan` >
  `Bitmap Heap Scan` / `Bitmap Index Scan` (the middle ground; combines
  multiple indexes via `BitmapAnd`/`BitmapOr`) > `Seq Scan`.
- A `Seq Scan` is not automatically wrong. Above ~5-10% of a table the planner
  correctly prefers sequential I/O to random index lookups. Only chase the
  Seq Scans that return a small fraction of a large table.

## Index types

- **B-tree** (default) covers `=`, range, `BETWEEN`, `IN`, `IS NULL`, prefix
  `LIKE 'foo%'`, and `ORDER BY`. For composite indexes, order columns
  equality-first, range-last, highest-cardinality equality column leading;
  a range column placed before an equality column forces a wider index scan.
- **Partial** (`CREATE INDEX ... WHERE status='pending'`) indexes only matching
  rows: smaller and cheaper. Used only when the query's `WHERE` implies the
  index predicate; a `status='shipped'` query won't touch it. The fix for a
  low-cardinality column the planner otherwise ignores.
- **Expression** (`CREATE INDEX ... ON t (lower(name))`) indexes a computed
  value. Used only when the query's expression matches *identically*:
  `WHERE lower(name)=?` hits it, `WHERE upper(name)=?` falls back to a Seq Scan.
- **Covering / `INCLUDE`** (`CREATE INDEX ... ON t (city) INCLUDE (name)`)
  appends non-key columns so a query needing only those columns gets an
  `Index Only Scan`. Watch `Heap Fetches` in the plan: `0` means fully served
  by the index; a nonzero value means the visibility map isn't set for those
  pages, so keep the table vacuumed for index-only scans to pay off.
- **GIN** for multi-valued columns: JSONB, arrays, full-text `tsvector`. Use
  `jsonb_path_ops` for a smaller index when you only query containment (`@>`).
  GIN only produces Bitmap scans (never an Index Only Scan) and has heavier
  write cost, so don't GIN a whole JSONB column when you query a couple of keys,
  index those keys with expression indexes instead.
- **BRIN** for large tables physically ordered by the indexed column
  (append-only timestamps, log/event tables). It stores per-block-range
  summaries, so it's tiny (kilobytes where a B-tree is megabytes) at the cost of
  coarser lookups. Useless if the column isn't correlated with physical order.
- **GiST** for geometric/spatial data, range types, and nearest-neighbor
  (`ORDER BY point <-> ?`) queries.

## ANALYZE, autovacuum, and bloat

Postgres's MVCC leaves dead tuples behind on every `UPDATE`/`DELETE`. Autovacuum
both reclaims them and refreshes planner statistics. Two failure modes:

- **Stale statistics** make the planner estimate on old row counts and pick the
  wrong plan. `ANALYZE` (or `VACUUM ANALYZE`) after any bulk change. For a
  skewed column the planner misjudges, raise its resolution:
  `ALTER TABLE t ALTER COLUMN c SET STATISTICS 1000;` then `ANALYZE t;`.
- **Bloat** from dead tuples the default autovacuum is too lazy to clear
  (`autovacuum_vacuum_scale_factor = 0.2` waits for 20% dead). Check
  `pg_stat_user_tables` (`n_dead_tup`, `last_autovacuum`); for a hot table,
  tune per-table (`ALTER TABLE t SET (autovacuum_vacuum_scale_factor = 0.02)`).
  Reclaim severe bloat with `pg_repack` (online), not `VACUUM FULL` (takes an
  exclusive lock that blocks all reads and writes).

## Write and bulk-load performance

- **`COPY`, not `INSERT`, for bulk loads.** It's the dedicated bulk path and
  far faster. If you must `INSERT`, batch thousands of rows per statement inside
  one transaction rather than row-at-a-time.
- **Drop indexes and constraints, load, then recreate.** Maintaining them
  per-row dominates load cost; foreign keys and triggers fire per row. Recreate
  indexes afterward, and raise `maintenance_work_mem` (which speeds `CREATE
  INDEX` and FK validation, not `COPY` itself) for that phase.
- **Cut checkpoint and WAL overhead during a big load:** raise `max_wal_size`
  so checkpoints fire on the timer, not every few GB. `UNLOGGED` tables skip
  WAL entirely for staging/reloadable data (lost on crash).
- **`ANALYZE` after loading.** A load leaves the planner with stats describing
  an empty table until you refresh them.

## Server config baseline

Postgres ships conservative defaults tuned for tiny hardware. Typical starting
points for a dedicated server (measure, don't cargo-cult):

- `shared_buffers` ≈ 25% of RAM. Check the cache hit ratio in
  `pg_statio_user_tables`; consistently below ~95-99% suggests raising it.
- `effective_cache_size` ≈ 50-75% of RAM. Planner hint only, allocates nothing;
  too low pushes the planner away from index scans.
- `work_mem` is *per sort/hash operation per query*, so multiply by concurrency
  before raising it. An `external merge Disk` line in a plan means a sort
  spilled and `work_mem` is too low for that query.
- `random_page_cost` ≈ 1.1 on SSD/NVMe (default 4.0 assumes spinning disk); the
  high default discourages index scans that are actually cheap on flash.
- `maintenance_work_mem` up to ~1 GB for faster VACUUM and index builds.

## Beyond indexes

When the plan already uses indexes and it's still slow, look at the query and
schema: a correlated subquery that should be a join, `SELECT *` where an
index-only scan over a few columns would do, `OFFSET`-based deep pagination
(prefer keyset/seek pagination on an indexed ordering), an `OR` across columns
that defeats a single index (a `UNION` of indexed lookups can beat it), or a
missing partition on a giant append-only table. Rewriting often beats another
index.

For schema-level conventions (types, constraints), see the `sql` rule.

## References

Official PostgreSQL docs (authoritative, prefer these):

- [Using EXPLAIN](https://www.postgresql.org/docs/current/using-explain.html)
  and [Planner statistics](https://www.postgresql.org/docs/current/planner-stats.html)
- [Index types](https://www.postgresql.org/docs/current/indexes-types.html)
  and [Index-only scans](https://www.postgresql.org/docs/current/indexes-index-only-scans.html)
- [Populating a database (bulk load)](https://www.postgresql.org/docs/current/populate.html)
- [pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html)
  and [Routine vacuuming](https://www.postgresql.org/docs/current/routine-vacuuming.html)
- [Resource consumption (memory settings)](https://www.postgresql.org/docs/current/runtime-config-resource.html)

Practitioner write-ups (useful, but verify against your version):

- [Crunchy Data: Postgres scan types in EXPLAIN plans](https://www.crunchydata.com/blog/postgres-scan-types-in-explain-plans)
- [Crunchy Data: Indexing JSONB in Postgres](https://www.crunchydata.com/blog/indexing-jsonb-in-postgres)
- [pganalyze: Understanding GIN indexes](https://pganalyze.com/blog/gin-index)
- [pganalyze: Optimizing bulk loads, COPY vs INSERT](https://pganalyze.com/blog/5mins-postgres-optimizing-bulk-loads-copy-vs-insert)
