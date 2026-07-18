---
paths:
  - "**/*.sql"
  - "**/migrations/**"
---

# SQL

## SQLite

For diagnosing and speeding up a slow query (reading `EXPLAIN QUERY PLAN`, the
`.expert` index recommender, index design), see the `optimize-sqlite` skill.

### Prefer STRICT tables

Add `STRICT` to every `CREATE TABLE` in new SQLite schemas:

```sql
CREATE TABLE people (name TEXT NOT NULL, age INTEGER) STRICT;
```

Without it, SQLite's flexible typing silently accepts text in an INTEGER column
and silently accepts nonsense column types (`DATETIME`, `UUID`, `BLOBB`) as
untyped. STRICT rejects both at definition and write time, turning
data-integrity mistakes into loud errors.

- Column types in a STRICT table MUST be one of `INT`, `INTEGER`, `REAL`,
  `TEXT`, `BLOB`, or `ANY`. Use `ANY` for a column that genuinely holds mixed
  types (it preserves the original type, unlike a non-STRICT column).
- Requires SQLite 3.37.0 (2021-11). Older engines can't read STRICT tables.
- No `ALTER` to add STRICT: convert an existing table by creating a new STRICT
  table and copying rows, which fails loudly if legacy data violates the types.

Reference: [Prefer strict tables in SQLite](https://evanhahn.com/prefer-strict-tables-in-sqlite/) by Evan Hahn
