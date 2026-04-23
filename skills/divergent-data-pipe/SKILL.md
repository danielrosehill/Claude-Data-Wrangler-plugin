---
name: divergent-data-pipe
description: Reconcile a canonical upstream data file with a downstream project that has diverged — the downstream has added enrichments, renamed columns, changed types, or restructured the data, so fresh upstream rows can't be loaded incrementally without transformation. Builds a mapping between upstream and downstream representations and generates an idempotent incremental sync script that ingests only new/changed rows from upstream, applies the transformation, and appends/upserts them into the downstream dataset. Use when a project's working data has evolved beyond the source and new source data needs to flow in without clobbering the divergence.
---

# Divergent Data Pipe

Bridge an upstream source and a downstream-project dataset that has diverged from it, then keep them in sync incrementally.

## Scenario

- **Upstream**: a canonical data file (CSV/Parquet/JSON/API) that keeps receiving new rows and the occasional row update.
- **Downstream**: a project-owned dataset derived from upstream but enriched, renamed, re-typed, restructured. It cannot be rebuilt from upstream alone — the project investments would be lost.
- **Problem**: naively re-loading upstream would either overwrite the downstream or miss the enrichments. A hand-rolled incremental load is fragile.

This skill's job is to (1) map upstream↔downstream and (2) produce a repeatable script that loads only new/changed upstream rows into downstream while preserving the divergence.

## When to invoke

- User says "the source file got new rows, how do I merge them into the project?", "my dataset has drifted from the source", "I need an incremental sync".

## Procedure

### Phase 1 — Diff and map

1. **Locate both sides** — upstream file/endpoint and downstream dataset.
2. **Profile each** independently — columns, types, row counts, primary/natural keys, last-modified column if any.
3. **Column mapping**:
   - Auto-suggest by name similarity, sample-value match, and type compatibility.
   - Confirm each mapping with the user: `upstream.col_x → downstream.col_y` or `upstream.col_x → (dropped)` or `downstream.col_z → (added by project, not in upstream)`.
   - Record renames, splits (one upstream column → multiple downstream), merges, and type casts explicitly.
4. **Transformation inventory** — for each upstream-to-downstream difference, record the transformation the downstream applied (ISO code enrichment, currency conversion, text parsing, text-to-numeric, categorical remapping). Route to plugin skills where applicable.
5. **Identify the key** — the upstream↔downstream row identity. Usually a stable upstream primary key preserved verbatim downstream. If there isn't one, build a composite or deterministic hash from stable columns; warn that lack of a key makes updates impossible (append-only).
6. **Identify the change-detection signal**:
   - New rows: upstream key not in downstream.
   - Updated rows: same key, differing upstream payload vs the downstream's `_source_*` shadow columns (see below).
   - Deleted rows: key in downstream but not in upstream — soft-delete by default; confirm policy.
7. **Write a mapping document** `divergent_pipe_mapping.md` — columns, transformations, key, change-detection strategy, collision rules.

### Phase 2 — Shadow columns (one-time augmentation)

To detect updates to rows that were already loaded, the downstream needs to remember the upstream state it last saw. Add shadow columns alongside the enriched downstream fields:

- `_source_ingested_at` — timestamp of last successful ingest for this row.
- `_source_row_hash` — hash of the upstream columns that map into downstream (exclude enrichment-only downstream columns).
- `_source_primary_key` — the upstream key (if different from downstream PK).

If the downstream is missing these, generate them from the current upstream once (best-effort reconstruction) and flag rows where reconstruction is ambiguous.

### Phase 3 — Generate the sync script

Emit `sync_from_upstream.py` (or `.sh` wrapping SQL for DB-backed downstreams). Structure:

```
1. Read upstream (full or since-last-sync via a watermark).
2. Compute the row hash per upstream row.
3. Left-join against downstream on the upstream key:
   - no match         -> new row: apply transformation, insert.
   - match, same hash -> skip.
   - match, diff hash -> update: apply transformation to *upstream fields only*,
                         preserve downstream enrichments and manual edits.
4. For keys present downstream but absent upstream:
   - soft-delete (flag a `_source_deleted_at` column) or skip, per policy.
5. Update _source_row_hash and _source_ingested_at on touched rows.
6. Write a run log: counts of inserted / updated / skipped / soft-deleted / errored.
```

The script must be:
- **Idempotent** — re-running without new upstream data does nothing.
- **Dry-run capable** — `--dry-run` prints the plan without writing.
- **Atomic per batch** — wrap in a transaction for SQL-backed downstreams; write to a temp file and rename for file-backed downstreams.
- **Backed up first** — per `CONVENTIONS.md`, confirm a downstream backup or create one before first real run.

### Phase 4 — First run and verify

1. Run in `--dry-run` mode and show the user the planned counts.
2. Confirm with the user before applying.
3. Run the real sync; compare before/after row counts, spot-check a few inserted and updated rows, review the run log.
4. Record the run in the downstream's `CHANGELOG.md` (via `add-changelog`).
5. Update the data dictionary with the new shadow columns and the sync procedure reference.

## Dependencies

```bash
pip install pandas pyarrow
# if downstream lives in a SQL DB
pip install SQLAlchemy psycopg[binary]  # or mysql / sqlite etc.
```

## Edge cases

- **Downstream mutates upstream-mapped columns by hand** — the hash comparison will see this as "upstream changed". Before first run, ask whether downstream edits to source-origin columns should be preserved (then lock those rows) or overwritten on upstream change. Offer a per-column policy.
- **Schema evolution in upstream** — new columns appear. Flag and ask whether to (a) add to downstream with default enrichment, (b) ignore, (c) require explicit mapping update. Do not auto-propagate schema changes.
- **Key changes upstream** — a row's key changes (upstream renumbered). Detect via content-similarity; ask user to pair manually. Never silently reassign.
- **Soft-delete vs hard-delete** — hard-deleting downstream rows risks losing enrichments. Default to soft-delete; require explicit confirmation for hard-delete.
- **Multiple upstream sources** — out of scope for a single pipe; the user should run this skill once per upstream.

## Safety

This skill writes into a dataset that represents real project investment. Follow `CONVENTIONS.md` rigorously:
- Confirm downstream backup before first real run.
- Dry-run first, always.
- The generated sync script must keep the dry-run and backup flags on by default.
