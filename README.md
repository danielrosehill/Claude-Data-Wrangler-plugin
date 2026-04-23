# Claude-Data-Wrangler

Data cleaning, enrichment, restructuring, and packaging skills for tabular and JSON datasets. Data visualisation is **out of scope** (handled by a separate plugin).

## Skills

### Cleaning & cleanliness

| Skill | Purpose |
|---|---|
| `data-cleanliness-scan` | Scan flat files (CSV/Parquet/JSON/Excel) and flag columns likely to fail SQL ingestion or analysis |
| `standardise-country-names` | Normalise inconsistent country names ("USA" vs "United States of America") |
| `text-to-numeric` | Parse formatted strings like `$4.27`, `1,234.56`, `€1.2M`, `(500)` into numeric columns |
| `unicode-consistency` | Detect and fix mixed Unicode normalisation, mojibake, invisible chars, confusables |
| `date-wrangling` | Convert dates/times between ISO 8601, epoch (s/ms/µs/ns), with/without timezone, fiscal, week-date |
| `iso-review` | Audit the dataset for fields that could be standardised to an ISO standard (3166, 4217, 639, 8601, LEI, ISIN, …) and optionally refactor |

### Enrichment

| Skill | Purpose |
|---|---|
| `add-iso3166` | Add ISO 3166 country codes (alpha-2/3, numeric) to datasets referencing countries |
| `enrich-with-currency` | Map ISO 3166 codes to ISO 4217 currency codes (plus name / symbol) |
| `data-enrichment` | Brainstorm and rank enrichment opportunities (temporal, geo, entity, FX, embeddings, holidays …) |

### Documentation & provenance

| Skill | Purpose |
|---|---|
| `add-data-dictionary` | Generate a data dictionary (Markdown / YAML / JSON / CSV) for a dataset |
| `update-data-dictionary` | Keep an existing data dictionary in sync after schema changes |
| `data-dictionary-export` | Export a data dictionary to a polished PDF via Typst |
| `add-changelog` | Maintain a dataset-focused `CHANGELOG.md` (Keep-a-Changelog, SemVer-adapted) |

### Reshape & format

| Skill | Purpose |
|---|---|
| `csv-to-json` | Bidirectional CSV ↔ JSON / JSONL conversion |
| `json-restructure` | Reshape JSON — flatten, nest, group-by, explode arrays, promote/demote fields |
| `data-shape` | Propose a normalised SQL schema (tables, keys, relationships) from a flat source |
| `data-comparability` | Align multiple datasets — reconcile headers, types, vocabularies, units — for merge/union |

### Privacy

| Skill | Purpose |
|---|---|
| `pii-flag` | Detect PII (names, emails, IDs, cards, coords, …) at cell-level with confidence scores |
| `synthetic-data-overlay` | Replace PII with realistic synthetic substitutes preserving shape and referential integrity |

### Packaging & targets

| Skill | Purpose |
|---|---|
| `database-guide` | Recommend a database backend (relational / analytical / document / graph / vector / time-series) |
| `parquet-jsonl-package` | Package a dataset as Parquet and/or JSONL with compression and partitioning |
| `sql-load` | Load a flat dataset into SQL (Postgres / MySQL / SQLite / MSSQL / DuckDB) with schema validation |
| `graph-database` | Reshape tabular/JSON data into nodes + edges, emit Cypher / GraphML / CSV bulk loads |
| `vector-upsert` | Embed text fields and upsert into a vector DB (Pinecone / Qdrant / Weaviate / pgvector / Chroma / Milvus) |
| `hf-dataset-push` | Publish a packaged dataset to Hugging Face Hub with dataset card |
| `api-loader` | Prepare and push data into a REST API or MCP server, from an OpenAPI spec or well-known SDK |
| `geodata-formatter` | Convert CSV / tabular geodata into GeoJSON (or NDGeoJSON) with CRS reprojection and geometry inference |
| `divergent-data-pipe` | Build an incremental sync from a canonical upstream into a downstream project that has diverged (renames / enrichments), preserving the divergence |

## Conventions

Every skill follows the safety and data-layout rules in [`CONVENTIONS.md`](CONVENTIONS.md). Highlights:

- **Backup-before-destruction** — any destructive edit (overwrite, mutate-in-place, remote load) must confirm an existing backup or create one first (file copy, Parquet/JSONL snapshot, or git commit).
- **New-file-by-default** — outputs get a suffix (`_iso3166`, `_numeric`, `_synthetic`); overwrite only on explicit user request.
- **Data dictionary is the provenance log** — every schema-changing operation writes a dated entry.
- **No plaintext secrets** — connection passwords and API keys are referenced via env vars, 1Password, or prompt-at-runtime.

## Typical pipeline

```
raw CSV
  → data-cleanliness-scan        (audit)
  → iso-review                   (flag standards opportunities)
  → unicode-consistency          (clean text)
  → standardise-country-names
  → add-iso3166
  → enrich-with-currency
  → text-to-numeric              ($4.27 → 4.27)
  → date-wrangling               (normalise to ISO 8601 / epoch)
  → pii-flag                     (before any external publication)
  → synthetic-data-overlay       (if needed)
  → add-data-dictionary          (or update)
  → add-changelog
  → data-shape                   (plan SQL schema)
  → parquet-jsonl-package
  → sql-load / hf-dataset-push / vector-upsert / graph-database / api-loader
  → data-dictionary-export       (share the PDF)
```

Each skill updates the data dictionary so provenance is preserved end-to-end.

## Installation

### Plugin

```bash
claude plugins install Claude-Data-Wrangler@danielrosehill
```

### Python dependencies (via uv)

The plugin's skills rely on a broad but optional dependency set. A [`uv`](https://docs.astral.sh/uv/)-backed installer is provided:

```bash
# install uv once
curl -LsSf https://astral.sh/uv/install.sh | sh

# install all dependencies into a local .venv
./scripts/install-deps.sh

# or just the core tabular stack
./scripts/install-deps.sh --minimal

# or a specific group (core, iso, dates, text, pii, enrichment, sql, vector, graph, api, hf)
./scripts/install-deps.sh --group vector

# activate the venv for subsequent skill runs
source .venv/bin/activate
```

Aggregated requirements live in [`requirements.txt`](requirements.txt). Each `SKILL.md` lists its own minimum dependencies so you can install per-skill if preferred.

## License

MIT — see [`LICENSE`](LICENSE).
