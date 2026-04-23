---
name: localization-headers
description: Produce localised versions of a dataset and/or its data dictionary with translated column headers (and optionally translated dictionary descriptions) so the same underlying data can be analysed by speakers of different languages. Use when the user wants frictionless multi-language packaging — e.g. English canonical plus Hebrew, Arabic, French, Spanish variants — without forking the underlying data.
---

# Localization Headers

Create language-specific views of a dataset where only the headers (and optionally the data dictionary text) are translated. The row data is unchanged unless the user asks for value-level localisation separately.

## When to invoke

- User wants to share a dataset with non-English-speaking analysts and needs translated column headers.
- User wants a multilingual data dictionary derived from one canonical version.
- Preparing a dataset for a multi-region team where each locale reads its own header language.
- User says "localise this dataset" or "make a Hebrew/Arabic/… version".

## Design principles

- **Canonical dataset stays untouched.** Localisation produces sibling files; it does not mutate the source.
- **Column order and content are preserved** across all language variants so joins and diffs work by position.
- **One source of truth for the mapping.** A single `header_translations.{csv,yaml}` file maps canonical headers to each locale. All language variants and the localised dictionaries are generated from this file. Re-running should be idempotent.
- **Low friction.** The user provides target language(s); everything else is automated. The user only has to approve the proposed translations.

## Procedure

1. **Confirm the canonical dataset and its "source" language** (usually English). If a data dictionary exists, treat it as authoritative for term meanings.
2. **Ask which target locale(s)** to produce. Accept BCP 47 tags (`he`, `ar`, `fr`, `es-MX`) or plain names.
3. **Build or load the translation manifest** `header_translations.csv` with columns: `canonical`, plus one column per target locale. If it already exists, load and only fill missing cells; do not overwrite existing translations without confirmation.
4. **Propose translations** for each missing cell:
   - Preserve units and codes untouched (`price_usd` stays `price_usd` — or the unit suffix stays `usd` with the word `price` translated).
   - Preserve the user's casing convention per locale (snake_case tokens translated word-by-word then rejoined; coordinate with `header-standardisation`).
   - For RTL languages (Hebrew, Arabic), produce native-script headers but keep ASCII/identifier-safe versions available on request for SQL consumption.
   - Flag ambiguous terms (e.g. `revenue` → `הכנסה` vs `פדיון`) and ask the user to pick once; reuse the choice across the dataset and dictionary.
5. **User reviews and edits the translation manifest.** Save it alongside the dataset so future runs are deterministic.
6. **Generate the localised files**:
   - `dataset.<locale>.csv` (or Parquet, matching source format) — identical rows, translated header row.
   - `data_dictionary.<locale>.md` (or matching format) — column names translated; if the user asked, descriptions translated too (mark machine-translated text clearly so a human reviewer can sign off).
   - Optional: a single multi-sheet Excel workbook with one tab per locale, if the user wants a bundled deliverable.
7. **Add a `localisation` section to the canonical data dictionary** listing the available locales, the manifest file, and a note that header translations are the authoritative mapping.
8. **Report**: files generated, locales covered, any terms the user was asked to disambiguate, and any headers left untranslated (with reason, e.g. proper nouns, product codes).

## Dependencies

```bash
pip install pandas pyyaml
```

Translation can use any available LLM call; prefer in-session translation so the user can review and correct interactively. Do not call external paid translation APIs without asking.

## Edge cases

- **RTL rendering** — CSV is direction-agnostic, but spreadsheet apps may reverse column order visually. Note this to the user; do not reorder columns.
- **Character encoding** — always write UTF-8 with BOM for Excel-friendly CSVs when the locale uses non-ASCII scripts; state the encoding in the report.
- **SQL-unsafe translated headers** — Hebrew, Arabic, CJK headers are valid identifiers in quoted form but awkward in practice. Offer to keep the canonical (English) headers for the SQL-bound export and only translate the dictionary.
- **Term consistency across datasets** — if the user has several datasets sharing vocabulary, suggest promoting the translation manifest to a shared glossary file they can reuse.
- **Value-level localisation** (translating cell values, not just headers) — out of scope here; flag it and offer a follow-up pass as a separate operation.
- **Re-running after the canonical schema changes** — detect added/removed/renamed canonical headers and surface them for translation; never silently drop a locale column.
