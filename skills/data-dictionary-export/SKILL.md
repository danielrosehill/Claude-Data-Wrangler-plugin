---
name: data-dictionary-export
description: Export an existing data dictionary to a polished PDF using Typst, with a branded title page, column reference table, provenance log, and known-issues section. Use when the user wants a shareable, printable, or client-facing version of a dataset's documentation.
---

# Data Dictionary Export (Typst → PDF)

Render an existing data dictionary as a PDF via Typst.

## When to invoke

- A `data_dictionary.{md,yaml,json,csv}` already exists.
- User asks to "export the dictionary", "make a PDF", "share the schema document".

## Procedure

1. **Locate the dictionary file** in the dataset's folder.
2. **Parse it** — handle Markdown, YAML, JSON, or CSV formats. Normalise to an internal structure:
   ```
   { dataset_name, source, format, rows, columns: [{name, type, description, units, nullable, example, notes}], provenance: [...], known_issues: [...] }
   ```
3. **Ask the user** for:
   - Output path (default: alongside the dictionary, `<stem>.pdf`).
   - Template style — plain, DSR-branded (via `typst-document-generator` plugin if available), or client-confidential. Default to plain unless the user has a preferred template configured.
   - Include a data sample table (first N rows)? Default no (to avoid leaking PII).
4. **Generate a Typst document** — sections:
   - Title page (dataset name, date, author).
   - Overview (source, format, row/column count).
   - Columns reference (multi-column table; wraps cleanly across pages).
   - Provenance log (dated list of transformations).
   - Known issues.
   - Appendix: sample rows (optional, PII-checked first).
5. **Compile** with `typst compile` to PDF. Verify exit code and output file presence.
6. **Report** the output path; offer to open it in the system PDF viewer.

## Preferred integration

If the `typst-document-generator` plugin is installed, prefer its `public-doc` or `dsr-client-confidential` skill for branding consistency. Otherwise emit a self-contained `.typ` file.

## Dependencies

- `typst` CLI installed and on PATH. If missing, report and point the user to `https://typst.app/docs/`.
- Standard library Python for parsing.

## Edge cases

- **Very wide column tables** — Typst handles landscape; switch orientation if columns > 8 or any cell is long.
- **Non-Latin scripts** in descriptions — ensure the Typst font supports them (default `New Computer Modern` may not). Fall back to `Noto Sans` if detected.
- **Incomplete dictionary** (TODO placeholders) — include them as-is but highlight in the PDF with a warning banner. Suggest running `update-data-dictionary` first.
- **Sample rows + PII** — if a sample appendix is requested, run `pii-flag` first or require explicit user confirmation.
