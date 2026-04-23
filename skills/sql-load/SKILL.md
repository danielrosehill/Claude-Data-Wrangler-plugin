---
name: sql-load
description: Load a flat dataset (CSV / Parquet / JSON / Excel) into a SQL database. Either uses an existing configured database connection or walks the user through configuring a new one (PostgreSQL, MySQL, SQLite, MSSQL, DuckDB). Creates the table if absent, validates schema, handles primary keys and indexes, and loads with chunked inserts for large files.
---

# SQL Load

Load a flat-file dataset into a SQL database.

## When to invoke

- User says "load this into Postgres / MySQL / SQLite", "put this in the database", "upload to my SQL server".
- Dataset is clean and the user wants it queryable via SQL.

## Supported backends

- **SQLite** — file-based, zero config; default for quick local loads.
- **PostgreSQL** — via `psycopg2` or `psycopg[binary]`.
- **MySQL** / MariaDB — via `PyMySQL` or `mysql-connector-python`.
- **Microsoft SQL Server** — via `pyodbc`.
- **DuckDB** — file-based analytics DB; best for Parquet-native workflows.

## Procedure

1. **Determine the connection**:
   - **Existing connection config** — check `$CLAUDE_USER_DATA/Claude-Data-Wrangler/config.json` for saved database profiles. List them, let the user pick.
   - **New connection** — ask the user for: backend, host/port OR file path, database name, username, and how to provide the password (env var name, 1Password reference via `op-vault`, or prompt at connection time). Never hard-code passwords in files. Save the non-secret parts of the profile to `$CLAUDE_USER_DATA/Claude-Data-Wrangler/config.json` if the user wants to reuse it.
2. **Confirm the target table**:
   - Table name (default: dataset filename stem, sanitised).
   - Schema (for Postgres / MSSQL).
   - Action if exists: `fail` (default), `append`, `replace`, `upsert` (requires primary key).
3. **Load the dataset** with pandas.
4. **Map dtypes to SQL types** — use the data dictionary if present to pin types; otherwise infer. Default mappings:
   - `int64` → `BIGINT` / `INTEGER`.
   - `float64` → `DOUBLE PRECISION` / `REAL`.
   - `object` (string) → `TEXT` / `VARCHAR(n)` — size from max length observed, padded.
   - `datetime64[ns]` → `TIMESTAMP`.
   - `bool` → `BOOLEAN` / `BIT`.
   Ask user to confirm for columns where inference is uncertain.
5. **Create the table** via `CREATE TABLE IF NOT EXISTS ...` (or `CREATE OR REPLACE` if requested). Respect primary key / not-null / index requests.
6. **Insert** in chunks (default 10k rows) using `to_sql(..., method='multi')` or backend-native bulk loaders (`COPY` for Postgres, `LOAD DATA INFILE` for MySQL) for large files.
7. **Validate** — row count `SELECT COUNT(*)` matches source; sample a few rows and compare.
8. **Report** — table name, row count, load duration, index/PK status.

## Connection config format

`$CLAUDE_USER_DATA/Claude-Data-Wrangler/config.json`:

```json
{
  "sql_profiles": {
    "local-postgres": {
      "backend": "postgresql",
      "host": "localhost",
      "port": 5432,
      "database": "analytics",
      "user": "daniel",
      "password_ref": {"type": "env", "name": "PGPASSWORD"}
    },
    "local-sqlite": {
      "backend": "sqlite",
      "path": "~/Documents/data/warehouse.db"
    }
  }
}
```

`password_ref` options:
- `{"type": "env", "name": "PGPASSWORD"}` — read from env var at connect time.
- `{"type": "op", "reference": "op://Private/postgres/password"}` — fetch via 1Password CLI.
- `{"type": "prompt"}` — prompt the user each run.

Never write plaintext passwords into this file.

## Dependencies

```bash
pip install pandas sqlalchemy
# per backend
pip install psycopg[binary]     # postgres
pip install pymysql             # mysql
pip install pyodbc              # mssql
pip install duckdb              # duckdb
```

## Edge cases

- **Schema drift** (file columns != table columns) — report diff; ask user whether to add columns, drop columns, or fail.
- **Character encoding** — ensure client/server encoding matches dataset encoding; default UTF-8.
- **Very large files** — use backend-native bulk loaders (`COPY FROM`, `LOAD DATA`) rather than `INSERT`. Stream from Parquet directly where possible.
- **Transactions** — wrap the load in a single transaction; if it fails mid-way, the user keeps the prior state.
- **PII** — if the dataset hasn't been PII-checked (see `pii-flag`), warn before loading into a shared database.
