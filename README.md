# Claude-Data-Wrangler

Data cleaning, enrichment, restructuring, and packaging skills for tabular and JSON datasets. Data visualisation is **out of scope** (handled by a separate plugin).

## Skills

| Skill | Purpose |
|---|---|
| `add-iso3166` | Add ISO 3166 country codes (alpha-2/3, numeric) to a dataset that references countries by name |
| `standardise-country-names` | Normalise inconsistent country names (e.g. "USA" vs "United States of America") |
| `enrich-with-currency` | Map ISO 3166 codes to ISO 4217 currency codes (and optionally name/symbol) |
| `text-to-numeric` | Parse formatted strings like `$4.27`, `1,234.56`, `€1.2M`, `(500)` into numeric columns, recording format metadata in the data dictionary |
| `add-data-dictionary` | Generate a data dictionary (Markdown / YAML / JSON / CSV) documenting every column, its type, and provenance |
| `update-data-dictionary` | Keep an existing data dictionary in sync after schema changes |
| `csv-to-json` | Convert between CSV and JSON / JSONL in either direction |
| `json-restructure` | Reshape JSON — flatten, nest, group-by, explode arrays, promote/demote fields |
| `parquet-jsonl-package` | Package datasets as Parquet and/or JSONL (compression, partitioning, schema enforcement) |
| `hf-dataset-push` | Publish a packaged dataset to Hugging Face Hub with dataset card and metadata |

## Typical pipeline

```
raw CSV
  → standardise-country-names
  → add-iso3166
  → enrich-with-currency
  → text-to-numeric (for $/€/etc. columns)
  → add-data-dictionary
  → parquet-jsonl-package
  → hf-dataset-push
```

Each skill updates the data dictionary so provenance is preserved end-to-end.

## Installation

```bash
claude plugins install Claude-Data-Wrangler@danielrosehill
```

## Python dependencies

Most skills use pandas plus one or two specialist libraries. Install the full set with:

```bash
pip install pandas pyarrow openpyxl pycountry babel huggingface_hub pyyaml
```

## License

MIT — see `LICENSE`.
