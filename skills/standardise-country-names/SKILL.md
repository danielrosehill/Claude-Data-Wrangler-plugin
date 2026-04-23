---
name: standardise-country-names
description: Standardise inconsistent country names in a dataset (e.g. "USA", "U.S.A.", "United States of America" → single canonical form). Use when a country column contains multiple spellings/aliases for the same country and the user wants them normalised.
---

# Standardise Country Names

Normalise a country column so each country has a single canonical spelling.

## When to invoke

- User says the dataset has inconsistent country names, duplicates like "USA" vs "United States", mixed casing, or aliases.
- Preparing data for `add-iso3166` — standardising first improves lookup hit rate.

## Procedure

1. **Load the dataset** and identify the country column.
2. **Profile the column** — print all unique values and their counts, sorted by frequency. Show this to the user before modifying anything.
3. **Pick a canonical standard** — ask the user which form they want:
   - ISO 3166 official short name (e.g. "United States", "Russian Federation") — default.
   - Common/colloquial (e.g. "United States", "Russia").
   - ISO alpha-2 code ("US", "RU").
   - ISO alpha-3 code ("USA", "RUS").
4. **Build the mapping** using `pycountry`:
   - Exact name match → canonical.
   - Known alias table (see `add-iso3166` skill for the baseline list).
   - Fuzzy match with confidence threshold (default 0.85); present low-confidence matches to the user for confirmation before applying.
5. **Apply the mapping** to a new column or overwrite the existing column — ask user which.
6. **Report** — before/after unique value counts, list of values that could not be resolved (leave original, flag in a `country_standardisation_status` column).
7. **Write output** with `_standardised` suffix.
8. **Update the data dictionary** if present.

## Dependencies

```bash
pip install pandas pycountry
```

## Edge cases

- **Historical names**: ask whether to map to the current successor state or keep original.
- **Disputed territories** (Taiwan, Kosovo, Western Sahara, Palestine): do not auto-resolve — ask the user.
- **Mixed case only** (e.g. "france" vs "France"): handle via case normalisation in the mapping key, preserving the canonical output casing.
