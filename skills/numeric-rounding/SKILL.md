---
name: numeric-rounding
description: Audit numeric columns for inconsistent decimal precision (e.g. some values at 4 dp, others at 2 dp) and round all values to a user-chosen precision. Use before SQL load or publishing when mixed precision would otherwise produce awkward `NUMERIC(x, y)` choices or misleading implied precision.
---

# Numeric Rounding

Bring numeric columns to a single, consistent decimal precision across the dataset.

## When to invoke

- User reports inconsistent decimal places in numeric columns (`1.2345` alongside `1.23`).
- Preparing a dataset for SQL load — need to decide `NUMERIC(p, s)` precision.
- Publishing a dataset where trailing zeros / variable precision would look sloppy.
- Merging datasets whose sources had different rounding conventions.

## Procedure

1. **Load dataset** and identify numeric columns (`float64`, `float32`, or object columns parseable as numeric — delegate to `text-to-numeric` first if they are strings).
2. **Profile current precision per column**:
   - Count the distribution of decimal places actually used (e.g. `85% at 4 dp, 15% at 2 dp`).
   - Report min/max absolute value per column (so the user can judge how much precision matters).
   - Flag columns where rounding would destroy meaningful digits (e.g. exchange rates, scientific measurements with many significant figures).
3. **Recommend a target precision per column**:
   - Currency amounts → 2 dp (most currencies) or 0 dp (JPY, KRW, ILS sometimes).
   - Percentages → 2 or 4 dp depending on use.
   - Lat/long coordinates → 6 dp (≈10 cm resolution) — delegate to `geodata-formatter` if coordinates are the target.
   - Scientific measurements → preserve significant figures; ask first.
   - IDs, counts → 0 dp (cast to int).
4. **Confirm with the user** the target precision for each column or group of columns. Offer a single dataset-wide default if columns are homogeneous.
5. **Apply rounding** using banker's rounding (`ROUND_HALF_EVEN`) by default for statistical neutrality; offer `ROUND_HALF_UP` if the user prefers (common in finance).
6. **Cast integer-valued floats to int** if all values are whole after rounding and the column semantics allow it.
7. **Write output** to `<name>_rounded.csv` (or Parquet if the source was Parquet) — do not overwrite the source.
8. **Record in the data dictionary**:
   - Final precision per column.
   - Rounding mode used.
   - Any columns where precision was deliberately preserved (and why).
   - Delegate to `update-data-dictionary` or `add-data-dictionary` if none exists.
9. **Report**: before/after precision summary, count of values changed per column, any columns skipped and why.

## Dependencies

```bash
pip install pandas
```

For exact decimal rounding (finance), use Python's `decimal.Decimal` rather than float rounding — floats cannot represent e.g. `0.1` exactly. Offer this when the column is currency.

## Edge cases

- **Floating-point artefacts** (`1.1 + 2.2 == 3.3000000000000003`) — rounding fixes these; note in the report.
- **Mixed-unit columns** (a "price" column where some rows are in USD and some in ILS) — rounding precision differs by currency. Delegate to `enrich-with-currency` to split first.
- **Scientific notation with tiny values** (`1.2e-8`) — absolute decimal-place rounding destroys them; use significant-figure rounding instead and note it.
- **Negative zero** (`-0.0`) — normalise to `0.0` in the output.
- **NaN / null preservation** — rounding must not convert nulls to zeros. Verify null counts before/after.
- **Integer columns accidentally typed as float** (`1.0`, `2.0`, …) — offer to cast to `Int64` (nullable int) rather than round.
