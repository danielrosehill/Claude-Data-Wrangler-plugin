---
name: iso-review
description: Scan a dataset for columns whose values could be standardised to an ISO standard (countries → ISO 3166, currencies → ISO 4217, languages → ISO 639, dates → ISO 8601, subdivisions → ISO 3166-2, units → ISO 80000, MIME → IANA, etc.). Reports non-compliance, proposes a canonical form, and optionally refactors existing values to the standard. Use when the user wants to audit a dataset for standards-compliance or bring ad-hoc values in line with formal standards.
---

# ISO Review

Audit a dataset for ISO-standardisable fields and optionally refactor to the standard.

## When to invoke

- User asks "is this using ISO standards?", "what could be standardised here?", "audit against ISO".
- Preparing a dataset for external distribution, where standards-compliance aids interoperability.

## Standards covered

| Standard | Scope | Detection heuristics |
|---|---|---|
| **ISO 3166-1** (countries) | alpha-2 (`US`), alpha-3 (`USA`), numeric (`840`) | Column names `country`, `nation`, `country_code`; values matching country names or 2/3-letter codes |
| **ISO 3166-2** (subdivisions) | e.g. `US-CA`, `GB-ENG` | State / province / region columns |
| **ISO 3166-3** (formerly-used) | Historical country codes | `USSR`, `DDR`, `YUG` values |
| **ISO 4217** (currencies) | `USD`, `EUR`, `JPY` | Currency columns, symbols in amounts |
| **ISO 639** (languages) | 639-1 (`en`), 639-2/3 (`eng`) | Language columns, free-text language labels |
| **ISO 8601** (dates/times) | `YYYY-MM-DD`, `YYYY-MM-DDTHH:MM:SSZ`, durations | Date-like columns in non-ISO formats |
| **ISO 80000 / SI units** | SI units and prefixes | Unit columns, mixed unit systems |
| **ISO 3166-1 alpha-2 in emails / URLs** (TLDs) | — | Domain / email columns with ccTLDs |
| **IANA time zones** (not ISO but standard) | `Europe/London` | Timezone columns |
| **IANA media types / MIME** | `application/json` | Content-type / format columns |
| **ISO 10962 (CFI)** | Financial instrument classification | Instrument columns |
| **ISO 6166 (ISIN)** | Securities identifiers | Security ID columns; checksum validation |
| **ISO 17442 (LEI)** | Legal Entity Identifier | Entity ID columns; 20-char format |

## Procedure

1. **Profile the dataset** — column names, types, samples, unique-value sets for low-cardinality columns.
2. **Pattern-match to standards** — use header heuristics (column-name keywords) plus value heuristics (regex, known-value sets from `pycountry`, `iso4217`, `langcodes`, etc.).
3. **Classify each candidate column**:
   - **Compliant** — already matches the standard cleanly.
   - **Partially compliant** — most values match; some don't (report exceptions).
   - **Non-compliant, easily refactorable** — values can be deterministically mapped (e.g. "United States" → "US").
   - **Non-compliant, ambiguous** — requires user input (e.g. short codes that could be 3166-1 or 3166-2, date formats `01/02/2024` that could be UK or US ordering).
4. **Produce a review report** `iso_review.md`:
   - Per column: applicable standard, compliance status, evidence, recommended canonical form, refactor feasibility.
   - Priority list — which columns to standardise first, based on impact + feasibility.
5. **Offer refactor mode** (require explicit user confirmation):
   - For each "easily refactorable" column, apply the mapping and add the standardised column (or overwrite, per user choice).
   - For dates, enforce ISO 8601 (with user-confirmed source-format assumption).
   - For currencies, promote symbols / free-text names to ISO 4217 codes.
   - Route through existing skills where they apply: `standardise-country-names`, `add-iso3166`, `enrich-with-currency`.
6. **Validate** — re-scan after refactor and report residual non-compliance.
7. **Update the data dictionary** — note the standard each column now follows.

## Dependencies

```bash
pip install pandas pycountry langcodes iso4217 python-stdnum python-dateutil babel
```

## Edge cases

- **Mixed standards in one column** — rare but real (e.g. a `country` column mixing alpha-2 and full names). Report and pick a target form with the user.
- **Date format ambiguity** (`01/02/2024`) — never guess. Require user confirmation; prefer source metadata or data dictionary for the answer.
- **Historical values** — ISO 3166-3 covers formerly-used codes; offer this rather than forcing a successor.
- **Checksum-validated identifiers** (ISIN, LEI) — verify the checksum; report invalid entries, do not silently accept.
- **Non-ISO regional standards** (e.g. FIPS codes) that look like ISO — note them, don't conflate.
- **Performance** — for very large datasets, sample for detection, then apply refactor in full-file pass.
