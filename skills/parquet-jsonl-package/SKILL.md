---
name: parquet-jsonl-package
description: Package a dataset as Parquet and/or JSONL for storage, distribution, or upload to data platforms (Hugging Face, S3, Wasabi, etc.). Handles partitioning, compression, schema enforcement, and side-by-side emission of both formats. Use when the user wants to produce analytics-friendly or ML-friendly files from a CSV/JSON/Excel source.
---

# Parquet & JSONL Packaging

Produce Parquet and/or JSONL output for a dataset, optionally partitioned and compressed.

## When to invoke

- User wants a Parquet file for analytics (DuckDB, Spark, pandas at scale, ML training).
- User wants JSONL for streaming or HF Datasets native ingestion.
- Preparing for upload via the `hf-dataset-push` skill.

## Procedure

1. **Confirm source and target formats** — JSONL, Parquet, or both.
2. **Load the dataset** (CSV, JSON, Excel).
3. **Schema enforcement** — ask whether to:
   - Auto-infer (pandas/pyarrow default).
   - Enforce a schema from the data dictionary if one exists.
   - Prompt for explicit types on each column (interactive).
4. **Parquet options**:
   - **Compression**: `snappy` (default, fast), `zstd` (better ratio), `gzip` (max portability).
   - **Row group size**: default `pyarrow`. Offer 64k / 256k rows for large datasets.
   - **Partitioning**: ask if the user wants to partition by a column (e.g. `country`, `year`). Produces a directory layout (`country=FR/data.parquet`).
5. **JSONL options**:
   - **Compression**: none (default), `gzip`, `zstd` — produce `.jsonl.gz` / `.jsonl.zst`.
   - **Line ordering**: preserve input order by default.
6. **Write outputs** next to the source (or to a user-specified directory):
   - `<stem>.parquet` (or `<stem>/` directory for partitioned).
   - `<stem>.jsonl` or `<stem>.jsonl.gz`.
7. **Validate**:
   - Round-trip load both outputs and check row count against source.
   - Print schema (pyarrow schema or JSON key sample).
   - Report file sizes and compression ratio.
8. **Update the data dictionary** with the new packaged file(s) and their paths.

## Dependencies

```bash
pip install pandas pyarrow
# optional
pip install zstandard
```

## Edge cases

- **Mixed-type columns** — Parquet requires a consistent type per column. Cast or split before writing; report casts.
- **Datetime handling** — Parquet has native timestamp types; JSONL must use ISO 8601 strings. Record the convention in the data dictionary.
- **Null representation** — Parquet handles null natively; JSONL uses `null`. Empty strings are *not* null.
- **Very large datasets** — stream in chunks rather than loading fully. Use `pyarrow.parquet.ParquetWriter` and chunked JSONL writes.
- **Nested data** — Parquet supports nested (struct/list) types natively. JSONL is naturally nested. If coming from CSV, document the nesting produced (via `json-restructure`) before packaging.
