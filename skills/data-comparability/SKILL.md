---
name: data-comparability
description: Analyse two or more datasets and suggest cleaning strategies that would make them comparable — aligning divergent header/column names, reconciling type mismatches (string vs int vs float), unifying unit conventions, and harmonising categorical value vocabularies. Use when the user has multiple datasets they want to merge, union, or cross-analyse and needs a concrete alignment plan before doing so.
---

# Data Comparability

Propose a concrete plan to align two or more datasets so they can be safely merged, unioned, or cross-analysed.

## When to invoke

- User has two or more tabular datasets (CSV / Parquet / Excel / JSON) and wants to compare, join, or union them.
- Column names differ between sources (e.g. `country` vs `nation` vs `Country_Name`).
- Same logical field has different types across files (e.g. `year` is int in one, string in another).
- Same categorical field has divergent vocabularies (e.g. `status`: `"active"` vs `"Active"` vs `"A"` vs `"1"`).

## Procedure

1. **Inventory inputs** — list each dataset's path, row count, and columns with dtypes and null rates.
2. **Produce a column alignment matrix** — a table with one row per logical field and one column per input dataset. Fill cells with the matching source column name (or `—` if missing). Flag:
   - **Renames**: same field, different header.
   - **Splits**: one source column corresponds to multiple fields in another.
   - **Merges**: multiple source columns correspond to one field in another.
   - **Missing**: field only exists in some sources.
3. **Type reconciliation** — for each aligned field, compare dtypes and propose a target type. Flag lossy casts (e.g. float → int would lose precision; report affected rows).
4. **Categorical vocabulary reconciliation** — for categorical / low-cardinality fields, dump the unique-value set per source side-by-side and propose a canonical vocabulary + mapping. Common patterns: case normalisation, short-code ↔ long-form (e.g. `M`/`Male`), boolean-ish (`Y`/`N`/`1`/`0`/`true`).
5. **Unit reconciliation** — if a field has units implied (currency, distance, time, temperature), detect mismatches from the data dictionary or sample values and propose canonical units.
6. **Key / join field check** — identify candidate join keys and validate uniqueness and overlap (how many keys match across sources).
7. **Produce a comparability plan** — an ordered list of operations needed before merge/union:
   - Renames to apply per source.
   - Type casts (with lossiness warnings).
   - Value mappings per categorical field.
   - Unit conversions.
   - Rows to drop / flag as irreconcilable.
8. **Link to executing skills** — pair each plan item with the plugin skill that performs it (e.g. `standardise-country-names`, `text-to-numeric`, `add-iso3166`). Don't execute automatically — this skill produces a plan; the user chooses what to run.
9. **Write the plan** to `comparability_plan.md` alongside the inputs, so the user can review and hand back.

## Dependencies

```bash
pip install pandas pyarrow
```

## Edge cases

- **Wildly different granularities** (one dataset is per-transaction, another per-month-aggregate) — flag and recommend aggregation before merge; do not silently propose a row-level join.
- **Encoding / locale differences** (same category in different languages) — detect with language heuristics; ask user for translation mapping rather than guessing.
- **Hidden keys** — sometimes the "same" record across sources needs a composite key. Propose candidate composites and report match rates.
