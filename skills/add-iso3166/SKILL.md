---
name: add-iso3166
description: Add ISO 3166 country codes (alpha-2, alpha-3, numeric) to a dataset that references countries by name but lacks standardised codes. Use when the user has a CSV/JSON/Parquet/Excel dataset with country names and wants ISO 3166 codes added as new columns/fields.
---

# Add ISO 3166 Country Codes

Add ISO 3166-1 codes to a dataset whose country column contains plain names.

## When to invoke

- Dataset has a country column (named `country`, `nation`, `country_name`, or similar) but no ISO code column.
- User asks to "add country codes", "add ISO codes", "enrich with ISO 3166".

## Procedure

1. **Locate the dataset** — confirm file path and format (CSV, JSON, JSONL, Parquet, XLSX).
2. **Identify the country column** — if multiple candidates exist or the column is ambiguous, ask the user which column holds the country name.
3. **Check for pre-existing codes** — if an ISO column already exists, report and ask whether to overwrite or skip.
4. **Load data** with pandas (`pd.read_csv`, `pd.read_json`, `pd.read_parquet`, `pd.read_excel`).
5. **Resolve country names to ISO codes** using `pycountry`:
   - Try exact match first via `pycountry.countries.get(name=...)` and `.lookup(...)`.
   - For fuzzy/partial matches, use `pycountry.countries.search_fuzzy(...)` with a confidence threshold.
   - Common aliases to hard-code before fuzzy matching: `USA`/`U.S.`/`U.S.A.` → `United States`, `UK` → `United Kingdom`, `Russia` → `Russian Federation`, `South Korea` → `Korea, Republic of`, `North Korea` → `Korea, Democratic People's Republic of`, `Ivory Coast` → `Côte d'Ivoire`, `Czech Republic` → `Czechia`, `Burma` → `Myanmar`.
6. **Add columns**: `iso3166_alpha2`, `iso3166_alpha3`, `iso3166_numeric`. Ask the user if they want all three or a subset — default to all three.
7. **Report unresolved rows** — list every country value that could not be mapped, with row counts. Do not silently drop or leave blank without reporting.
8. **Write output** — save alongside the input with `_iso3166` suffix by default (e.g. `countries.csv` → `countries_iso3166.csv`), preserving the input format. Confirm path with user if ambiguous.
9. **Update the data dictionary** — if a data dictionary exists in the same folder (see `add-data-dictionary` / `update-data-dictionary` skills), add the new columns. If none exists, offer to create one.

## Dependencies

```bash
pip install pandas pycountry openpyxl pyarrow
```

## Edge cases

- **Subnational regions** (e.g. "Scotland", "Catalonia") — flag and ask user whether to map to parent country or leave blank.
- **Historical entities** ("USSR", "Yugoslavia", "Czechoslovakia") — ISO 3166-3 covers these; offer that as an option.
- **Multi-country rows** (e.g. "Germany / France") — flag and ask user how to handle (split, skip, keep first).
- **Empty / null country values** — leave ISO columns null; report count.
