---
name: enrich-with-currency
description: Add ISO 4217 currency codes to a dataset by direct mapping from ISO 3166 country codes. Use when the dataset already has country codes and the user wants the local currency code (and optionally currency name/symbol) appended.
---

# Enrich With Currency (ISO 4217)

Map ISO 3166 country codes to ISO 4217 currency codes.

## When to invoke

- Dataset has ISO 3166 codes (alpha-2, alpha-3, or numeric) and the user wants currency information added.
- If only country names are present, invoke `add-iso3166` first.

## Procedure

1. **Locate the dataset** and confirm format.
2. **Identify the ISO 3166 column** — auto-detect `iso3166_alpha2`/`alpha3`/`numeric` or `country_code`. Ask if ambiguous.
3. **Load the country→currency mapping**:
   - Primary source: `pycountry` currencies via country subdivisions is incomplete; use the ISO 4217 country-currency table. Recommended library: `babel.numbers.get_territory_currencies(territory, date)` which returns currently-used currencies for a country code. Install with `pip install babel`.
   - Fallback: embed a static `country_alpha2 → currency_alpha3` map (e.g. from the `iso4217` package or a maintained CSV).
4. **Add columns** (ask which subset, default all):
   - `currency_code` (ISO 4217 alpha-3, e.g. `USD`, `EUR`)
   - `currency_numeric` (ISO 4217 numeric)
   - `currency_name` (e.g. "United States dollar")
   - `currency_symbol` (e.g. `$`, `€`)
5. **Handle multi-currency territories** — some countries use multiple currencies (e.g. Zimbabwe, Panama). Default to the most commonly used; flag the row and list alternatives in a notes column if the user wants.
6. **Handle currency unions** — Eurozone members all map to EUR; CFA franc zones map to XOF/XAF. This should fall out of the mapping naturally.
7. **Report unresolved rows** and write output with `_currency` suffix.
8. **Update the data dictionary**.

## Dependencies

```bash
pip install pandas pycountry babel
```

## Edge cases

- **Dependent territories** (e.g. Puerto Rico → USD, Greenland → DKK) — verify the mapping source covers these.
- **Countries with dual currencies** — document the chosen default in the data dictionary.
- **Historical currencies** — out of scope; this skill maps to currently-active currencies only.
