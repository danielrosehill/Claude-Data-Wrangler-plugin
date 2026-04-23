---
name: header-standardisation
description: Audit and standardise a dataset's header row against a naming convention (snake_case, camelCase, Title Case, kebab-case) and verify consistency with an existing or forthcoming data dictionary. Use when preparing a dataset for SQL loading, publishing, or when header inconsistency (mixed casing, spaces, punctuation, abbreviation drift) is blocking downstream work.
---

# Header Standardisation

Check and normalise the header row of a flat dataset so every column name follows one convention, and reconcile against a data dictionary if one exists.

## When to invoke

- User wants to check that the header row adheres to a standard (e.g. snake_case).
- User is about to create a data dictionary and wants headers normalised first so the dictionary can mirror them.
- Existing data dictionary uses one convention but the dataset's headers drifted.
- Preparing for SQL load — mixed-case or space-containing headers are fragile.

## Conventions supported

- `snake_case` — lowercase, underscores (SQL-friendly, default recommendation)
- `camelCase` — first word lowercase, subsequent capitalised
- `PascalCase` — all words capitalised, no separator
- `kebab-case` — lowercase, hyphens (avoid for SQL)
- `Title Case` — human-friendly, space-separated
- `SCREAMING_SNAKE_CASE` — constants/enums

## Procedure

1. **Load only the header row** of the dataset (pandas `nrows=0` or CSV sniff). Do not load the full dataset unless the user asks for a rename-and-save in the same pass.
2. **Profile the current headers**:
   - Detect the dominant convention (if any) using simple heuristics — count headers matching each pattern, report the split.
   - Flag headers with: whitespace, punctuation other than `_`/`-`, leading digits, reserved SQL keywords, duplicates (case-insensitive), non-ASCII characters, unit suffixes inconsistently placed (`price_usd` vs `USDPrice`).
3. **Ask the user** which convention to apply if unclear. Default to `snake_case` for anything destined for SQL or Parquet.
4. **Check against a data dictionary** if `data_dictionary.{md,csv,yaml,json}` exists alongside the dataset:
   - List headers present in the data but missing from the dictionary, and vice versa.
   - Flag case/spelling mismatches (`customer_id` in data vs `CustomerID` in dictionary).
5. **Propose a rename map** — show a two-column table (`original` → `standardised`) for user confirmation before touching the file.
6. **Apply the rename** to a new file (`<name>_headers-std.csv` by default); do not overwrite the source unless the user explicitly asks.
7. **Update the data dictionary** column names to match if one exists (delegate to `update-data-dictionary` skill).
8. **Report**: convention applied, number of headers changed, any ambiguous cases that needed user input, and warnings (SQL reserved words, duplicates after normalisation).

## Dependencies

```bash
pip install pandas
```

## Edge cases

- **Duplicate headers after normalisation** (`Customer ID` and `customer_id` both becoming `customer_id`) — stop and ask the user how to disambiguate; do not silently suffix with `_1`, `_2`.
- **Non-ASCII headers** (Hebrew, CJK, accented Latin) — ask before transliterating. If the dataset is intended for localisation, keep original and delegate to `localization-headers`.
- **Units inside headers** (`price_usd`, `weight_kg`) — preserve unit suffixes; do not strip them.
- **Leading digits** (`2024_revenue`) — SQL-unsafe; prefix with `_` or `yr_` and flag.
- **Very long headers** (>63 chars for Postgres) — warn; suggest abbreviation and record the mapping in the dictionary.
