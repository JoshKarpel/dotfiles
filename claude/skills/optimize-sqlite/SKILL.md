---
name: optimize-sqlite
description: >
  SQLite performance: query optimization plus write and connection tuning. MUST
  be invoked when a SQLite query is slow, a query needs an index, EXPLAIN QUERY
  PLAN shows a full-table SCAN, inserts/writes are slow, or you're choosing an
  index or connection PRAGMAs. Covers reading EXPLAIN QUERY PLAN, the
  experimental `.expert` index recommender, index types (covering, expression,
  partial), ANALYZE / sqlite_stat1, transaction and bulk-insert speed, and the
  WAL + synchronous=NORMAL connection PRAGMA baseline.
when_to_use: >
  Use for "this SQLite query is slow", "what index should I add", "why is this
  doing a full scan", "EXPLAIN QUERY PLAN says SCAN", "recommend an index",
  ".expert", "USE TEMP B-TREE FOR ORDER BY", "slow inserts", "bulk load",
  "should I use WAL", "which PRAGMAs", or when a migration adds an index and you
  want to confirm it's right. For schema design conventions (STRICT tables) see
  the `sql` rule, not this skill.
---

# Optimizing SQLite Queries

## The Loop

1. **Get a realistic query and database.** Index recommendations depend on real
   cardinality; a toy DB with 10 rows won't reveal the scan that hurts at
   500k. Point the tools at a copy of production-scale data when you can.
2. **Read the plan.** `EXPLAIN QUERY PLAN <query>;` shows how SQLite executes it
   today. Map the signals below to an action.
3. **Get index candidates** from `.expert` (below). It reads the actual schema
   and data and proposes `CREATE INDEX` statements.
4. **Judge, don't paste.** Expert optimizes the query *shape*, blind to which
   parameter value you'll bind and to your write load. Weigh each candidate
   against real selectivity and index-maintenance cost before adopting it.
5. **Apply and re-check the plan** on a copy. A speedup that doesn't change the
   plan (SCAN → SEARCH, or a dropped TEMP B-TREE) didn't happen.

## Reading EXPLAIN QUERY PLAN

Map the signal to the fix:

- `SCAN <table>` with no index: full-table scan. A candidate for an index when
  the `WHERE`/`JOIN` on that table is selective. A `SCAN` on a small lookup
  table, or one whose predicate matches most rows, is fine, leave it.
- `SEARCH <table> USING INDEX <name> (...)`: index is doing its job.
- `USING COVERING INDEX`: the index answers the query without touching the
  table row at all. Ideal for a hot read path. Reach it by adding the selected
  (non-predicate) columns to the index so every column the query needs lives in
  the index.
- `USE TEMP B-TREE FOR ORDER BY` / `FOR GROUP BY`: SQLite is sorting because no
  index provides the order. A composite index whose leading columns match the
  `ORDER BY`/`GROUP BY` removes the sort.

## `.expert`: the CLI index recommender

`.expert` is a `sqlite3` CLI command: issue it, then the query on the next line.
It prints recommended `CREATE INDEX` statements and the resulting plan, or
`(no new indexes)`:

```text
sqlite> .expert
sqlite> SELECT * FROM users WHERE city=? AND age>?;
CREATE INDEX users_idx_2010f75a ON users(city, age);
SEARCH users USING INDEX users_idx_2010f75a (city=? AND age>?)
```

Run it non-interactively by piping both lines in:

```bash
printf '.expert\nSELECT * FROM users WHERE city=? AND age>?;\n' | sqlite3 app.db
```

Verified behavior (sqlite3 3.46.1):

- **Read-only.** It builds candidate indexes in temporary connections; nothing
  is written to your database, so it's safe to run against a real file.
- **Dedups against existing indexes.** If an adequate index already exists it
  returns `(no new indexes)` rather than a near-duplicate.
- **`--verbose`** prints the full candidate list it considered, each annotated
  with `sqlite_stat1` selectivity (`-- stat1: <rows> <avg-rows-per-key>`), then
  the ones it chose. This is the useful mode: it shows *why* an index was or
  wasn't picked.
- **`--sample PERCENT`** gathers temporary distribution stats from that percent
  of rows so recommendations reflect real data skew, not schema alone (default
  is 0, schema-only). Use `--sample 100` on small databases; drop the percent
  on large tables where full sampling is too slow.

```bash
printf '.expert --verbose --sample 100\n%s\n' "$QUERY" | sqlite3 app.db
```

### Judgment: where `.expert` is blind

- **It optimizes the query shape, not your bound value.** For
  `WHERE status=?` on a column that's 90% `'shipped'`, it will happily
  recommend an index on `status`. That index helps the rare value and is
  useless (or a net loss, once you count write cost) for the common one. You
  know the value distribution; it doesn't. Verify against real selectivity.
- **It ignores write amplification.** Every index it proposes is another
  structure to maintain on every `INSERT`/`UPDATE`/`DELETE`. On a write-heavy
  table, decline indexes that only shave a rare read.
- **It's experimental.** SQLite documents that the interface may change or be
  removed. Treat output as a suggestion to confirm with `EXPLAIN QUERY PLAN`,
  never a line to paste unread into a migration.

## Index types beyond a plain column

Plan tags and gotchas below are verified on sqlite3 3.46.1.

- **Covering index** holds every column the query touches, so the row is never
  read. The plan shows `USING COVERING INDEX`. Turn a `USING INDEX` into a
  covering one on a hot read path by appending the selected columns (after the
  predicate columns) to the index.
- **Expression index** (`CREATE INDEX i ON t(price*qty)`) indexes a computed
  value. The planner uses it only when the query's expression is written
  *identically*: `WHERE price*qty > ?` hits it, `WHERE qty*price > ?` falls back
  to a `SCAN`. The expression must be deterministic and reference only that
  table.
- **Partial index** (`CREATE INDEX i ON t(created) WHERE status='pending'`)
  indexes only matching rows, so it's smaller and cheaper to maintain. The
  planner uses it only when the query's `WHERE` implies the index predicate;
  `status='shipped'` won't touch it. Ideal when reads target a hot subset of a
  large table.

## ANALYZE and stats

Without stats, the planner guesses cardinality and can pick a worse index.
`ANALYZE;` populates `sqlite_stat1` from the real data so the planner chooses on
facts. Re-run it after large data changes or after adding indexes. `PRAGMA
optimize;` (run periodically, e.g. before closing a connection) refreshes stats
incrementally and is the low-effort modern path.

This is distinct from `.expert --sample`: `ANALYZE` persists stats into the
database for the live planner; `--sample` gathers throwaway stats only to inform
one recommendation run.

## Write and bulk-insert performance

- **Wrap batched writes in one explicit transaction.** The largest single win,
  often orders of magnitude: outside a `BEGIN`/`COMMIT` every `INSERT` is its
  own transaction with its own durability sync. Group many writes into one.
- **Reuse one prepared statement**, binding new values per row, rather than
  building fresh SQL each time. Avoids re-parsing and keeps values out of the
  SQL text.
- **Create indexes after a bulk load, not before.** Maintaining indexes during
  the load makes every insert do index work; build them once the rows are in.
- **Don't hardcode the bind-parameter cap.** Multi-row `INSERT ... VALUES` is
  bounded by the compiled `SQLITE_MAX_VARIABLE_NUMBER`. The widely-cited 32766
  is build-specific (this CLI build reports 250000). Read the real limit with
  `sqlite3 db '.limits variable_number'` before sizing a batch.

## Connection PRAGMAs

Most PRAGMAs reset to defaults on every new connection, so a pooled app applies
them right after opening each one. A high-value baseline for a concurrent
read/write workload:

```sql
PRAGMA journal_mode = WAL;      -- concurrent readers alongside a writer; persists in the file
PRAGMA synchronous = NORMAL;    -- sync only at checkpoints; still corruption-safe under WAL
PRAGMA busy_timeout = 5000;     -- wait on a lock instead of erroring with SQLITE_BUSY
PRAGMA cache_size = -20000;     -- negative value is KiB, so about 20 MB of page cache
PRAGMA temp_store = MEMORY;     -- sorts and temp tables in RAM
```

- `journal_mode = WAL` and `page_size` persist in the database file; the rest
  are per-connection. `synchronous = NORMAL` under WAL drops an fsync on every
  commit for a small durability window (the last transaction can roll back on an
  OS crash, never corruption).
- WAL read speed degrades as the log grows, so keep checkpoints running. The
  default auto-checkpoint (~1000 pages) usually suffices; bound growth with
  `PRAGMA journal_size_limit` or an occasional `PRAGMA wal_checkpoint(TRUNCATE)`.

## Beyond indexes

An index is the common fix but not the only one. When the plan is already using
indexes and it's still slow, look at the query itself: a correlated subquery
that could be a join, `SELECT *` where a covering index over a few columns would
do, `OR` across columns that defeats a single index (a `UNION` of two indexed
lookups can beat it), or a schema that forces the scan. Rewriting the query or
schema often beats adding another index.

For schema-level conventions (STRICT tables, type choices), see the `sql` rule.

## References

Official SQLite docs (authoritative, prefer these):

- [The `.expert` command](https://www.sqlite.org/cli.html#index_recommendations_sqlite_expert_)
- [The Query Planner](https://www.sqlite.org/queryplanner.html) and
  [EXPLAIN QUERY PLAN](https://www.sqlite.org/eqp.html)
- [Query Planning with indexes](https://www.sqlite.org/optoverview.html)
- [Write-Ahead Logging (WAL)](https://sqlite.org/wal.html) and
  [PRAGMA reference](https://www.sqlite.org/pragma.html)
- [Partial indexes](https://www.sqlite.org/partialindex.html) and
  [Indexes on expressions](https://www.sqlite.org/expridx.html)

Practitioner write-ups (useful, but verify against your version):

- [phiresky: SQLite performance tuning](https://phiresky.github.io/blog/2020/sqlite-performance-tuning/)
- [Clément Joly: SQLite PRAGMA cheatsheet](https://cj.rs/blog/sqlite-pragma-cheatsheet-for-performance-and-consistency/)
- [Jason Feinstein: Squeezing performance from SQLite](https://medium.com/@JasonWyatt/squeezing-performance-from-sqlite-insertions-971aff98eef2)
- [avi.im: inserting one billion rows in SQLite under a minute](https://avi.im/blag/2021/fast-sqlite-inserts/)
