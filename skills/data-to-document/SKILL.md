---
name: data-to-document
description: Generate a polished PDF document from a dataset using Typst, with layout chosen to match the data shape (wide tables → landscape multi-page reference, narrow tables → portrait report, per-record → one-record-per-page card/profile layout, grouped → sectioned report). Supports user-selected field subsets, custom column labels, optional filtering/sorting, cover page, summary stats, and branded templates. Use when the user wants the dataset (or a slice of it) rendered as a shareable/printable document rather than a spreadsheet export.
---

# Data to Document (Typst → PDF)

Render a dataset — or a user-defined slice of it — as a PDF via Typst, with layout driven by data shape.

## When to invoke

- User asks "make a PDF of this data", "generate a report from this CSV", "print-ready document from my dataset", "turn these records into a profile document".
- User wants to share a dataset with a non-technical audience and a spreadsheet won't do.

## Layouts

The skill picks a layout based on data shape (and lets the user override):

| Shape | Layout | Description |
|---|---|---|
| Small narrow table (<10 cols, <50 rows) | **Report** (portrait) | Title, intro, table, footer |
| Wide table (>10 cols) | **Landscape reference** | Landscape orientation; column groups split across page blocks if needed |
| Many rows (>100) with logical groups | **Sectioned report** | Grouped by a user-chosen column; one section per group with a summary |
| Detailed per-record content | **One-per-page profile** | One record per page — label/value pairs, good for directory-style docs |
| Summary / dashboard | **Exec summary** | Page 1 key stats + top-N; appendix with full detail |

## Inputs to gather

1. **Dataset path** and format.
2. **Field selection** — which columns to include; default all non-PII.
3. **Custom labels** — display name per column (e.g. `iso3166_alpha2` → "Country Code"). Provide an interactive mapping or a YAML config.
4. **Filters / sort** — optional `WHERE` and `ORDER BY` equivalent expressed in pandas terms.
5. **Grouping** — column to group by (for sectioned report).
6. **Layout override** — let the user force a layout if the auto-pick is wrong.
7. **Template** — plain (default), branded (if `typst-document-generator` plugin is installed), or user-supplied `.typ`.
8. **Title / subtitle / author / date** — metadata for the cover page.
9. **Summary stats toggle** — include min/max/mean/count per numeric column? Default yes for sectioned and exec-summary layouts.

## Procedure

1. **Locate and load the dataset**. Profile columns (dtypes, cardinalities, null rates).
2. **Suggest a layout** based on shape; confirm with user.
3. **Interactive field selection** — list columns with defaults suggested. Let user drop columns and edit display labels. Save the selection as a side-car config `data_to_document_config.yaml` alongside the dataset so the same document can be regenerated later.

   ```yaml
   title: "Customers — Q1 2026"
   subtitle: "Tier-1 accounts"
   author: "Operations"
   layout: sectioned
   group_by: country_name
   sort_by: [country_name, -revenue_numeric]
   filter: "tier == 'T1' and active == True"
   fields:
     - column: name
       label: "Customer"
       width: 30%
     - column: country_name
       label: "Country"
       width: 15%
     - column: revenue_numeric
       label: "Revenue (USD)"
       width: 15%
       format: "#,##0"
     - column: signed_at
       label: "Signed"
       format: "%Y-%m-%d"
   summary_stats: true
   template: plain
   ```
4. **Apply filter / sort / grouping** via pandas.
5. **Render a Typst document**:
   - Cover page (title, subtitle, author, date, record count).
   - Body per layout:
     - **Report**: single table, column widths from config.
     - **Landscape reference**: landscape page, wide table; split column groups if width still overflows.
     - **Sectioned**: heading per group, inline summary stats row, table per group.
     - **One-per-page profile**: one record per page as a label/value block, optional photo/avatar column if a URL path is supplied.
     - **Exec summary**: first page KPIs (counts, top-N by a measure), appendix with full rows.
   - Footer with page numbers and generation timestamp.
6. **Number / date formatting** — honour per-field `format` specifiers; default to dataset-locale-aware formatting via `babel`.
7. **Compile**:
   ```bash
   typst compile document.typ document.pdf --input data=<path>.json
   ```
   Pass the filtered dataset to Typst as a JSON input so the template stays data-agnostic.
8. **Validate** — check exit code, PDF page count sanity, and that the record count matches filtered rows.
9. **Report** output path; offer to open the PDF.
10. **Update the data dictionary** with a note that a document was generated from this slice (skill + date + config reference).

## Preferred integration

If the `typst-document-generator` plugin is installed, delegate template selection to its `public-doc` / `personal-doc` / `dsr-client-confidential` skills for visual consistency with other documents. Otherwise emit a self-contained standalone `.typ` file.

Related: `data-dictionary-export` produces a similar PDF but specifically for the dictionary file; this skill produces a PDF of the *data itself*.

## Dependencies

- `typst` CLI on PATH — install from https://typst.app/docs/.
- Python: `pandas`, `pyyaml`, optionally `babel` for locale-aware number/date formatting.

```bash
pip install pandas pyyaml babel
```

## Edge cases

- **Very wide tables that still overflow landscape** — split into column groups across multiple table blocks within the same section, each block sharing a sticky key column (e.g. the customer name).
- **Very large datasets (>thousands of rows)** — warn the user; offer (a) filter / sort / top-N, (b) sampling, (c) sectioned report where each section stays short. Refuse to silently produce a 10,000-page PDF.
- **PII-heavy columns** — run `pii-flag` first and exclude flagged columns by default; require explicit opt-in to include them.
- **Non-Latin scripts** — ensure the Typst font covers them (Noto Sans fallback); test rendering before declaring success.
- **Custom labels collision** — two columns mapped to the same label → warn and refuse.
- **Nested JSON values** — flatten via `json-restructure` or stringify with a length cap before rendering; long JSON in a cell will overflow.

## Safety

This skill is read-only on the source dataset and writes a new PDF alongside it. No backup policy step required unless the user asks it to overwrite an existing PDF — in which case follow `CONVENTIONS.md` and rename the prior output with a timestamp.
