---
name: update-data-dictionary
description: Update an existing data dictionary to reflect new columns, changed types, renamed fields, dropped columns, or new transformations/provenance entries. Use after running any operation that modifies a dataset's schema (add-iso3166, enrich-with-currency, text-to-numeric, json-restructure, etc.).
---

# Update Data Dictionary

Keep an existing data dictionary in sync with the current dataset.

## When to invoke

- A schema-changing operation just ran and the dataset's folder contains a `data_dictionary.{md,yaml,json,csv}`.
- User says "update the data dictionary", "re-document", "re-profile".
- Another wrangler skill needs to log a transformation.

## Procedure

1. **Find the dictionary** — look for `data_dictionary.*` in the dataset's folder. If none exists, suggest `add-data-dictionary` instead.
2. **Load the current dataset** and profile columns.
3. **Diff against the existing dictionary**:
   - **New columns** — present in data, missing from dictionary → add row with stub description, ask user to fill in.
   - **Removed columns** — present in dictionary, missing from data → mark as "REMOVED <date>" or offer to delete the row (ask user).
   - **Type changes** — update the type column; log in provenance.
   - **Renamed columns** — heuristic only; ask the user to confirm rename mappings rather than guessing.
4. **Append to the provenance / transformations section** with today's date and a one-line summary of what changed.
5. **Preserve user-written descriptions** — never overwrite a description the user has filled in. Only touch auto-generated fields (type, examples, nullability).
6. **Write the updated dictionary** back to the same file, preserving its format (md/yaml/json/csv).
7. **Report** a summary diff: N columns added, M removed, K types changed.

## Dependencies

```bash
pip install pandas pyarrow openpyxl pyyaml
```

## Edge cases

- **Markdown round-trip** — parse the existing columns table carefully; preserve any additional text sections (notes, known issues) that the user has added by hand.
- **Multiple dictionary files** — if both `data_dictionary.md` and `data_dictionary.yaml` exist, ask the user which is canonical; optionally update both.
- **Dictionary out of date with multiple intermediate changes** — the provenance log may have gaps. Log today's transformation; flag the gap but don't fabricate history.
