---
name: unicode-consistency
description: Assess whether a dataset uses a consistent Unicode character set and normalisation form across its text columns. Detects mixed scripts, mixed normalisation forms (NFC/NFD/NFKC/NFKD), mojibake, mixed encodings, zero-width characters, confusables (homoglyphs), and BOM issues. Produces a remediation script with proposed fixes. Use when downstream text processing, search, or storage depends on clean Unicode hygiene.
---

# Unicode Consistency

Audit and remediate Unicode issues in text columns.

## When to invoke

- User suspects "weird characters" in the data.
- Search / joins on text keys return inconsistent results (usually a normalisation or invisible-char issue).
- Dataset came from multiple sources with different encodings / input methods.
- Preparing text for embedding (see `vector-upsert`) or search indexing.

## Checks performed

1. **File / column encoding** — detect declared vs actual encoding using `chardet` or `charset-normalizer`; flag mismatches.
2. **Normalisation form** — for each text column, sample values and check whether they are consistently NFC (or NFD/NFKC/NFKD). Mixed forms cause key mismatches that look identical to a human.
3. **Script mixing within a value** — e.g. Latin + Cyrillic in the same "word" (`аpple` with Cyrillic `а` instead of Latin `a`). Detect via `unicodedata.category` / `unicodedata.name` script inspection.
4. **Confusables / homoglyphs** — use the Unicode confusables table (`confusable_homoglyphs` / `uniseg`) to flag values likely to be spoofed or accidentally copy-pasted.
5. **Invisible characters** — zero-width space (U+200B), zero-width joiner (U+200D), soft hyphen (U+00AD), left-to-right / right-to-left marks (U+200E/F), BOM (U+FEFF) embedded mid-string.
6. **Whitespace variants** — non-breaking space (U+00A0), em/en spaces, thin space, ideographic space — all commonly confused with regular space.
7. **Quote / dash variants** — smart quotes (`"`, `'`, `'`) vs ASCII quotes, em-dash / en-dash vs hyphen-minus.
8. **Emoji and sequence completeness** — broken zero-width-joiner sequences from lossy copy/paste.
9. **Mojibake patterns** — double-encoded UTF-8 (`Ã©` for `é`, `â€™` for `'`, `ä¸­` for `中`). Detect via statistical patterns.
10. **Case-folding pitfalls** — Turkish `I`/`ı`, German `ß` — flag if the dataset relies on case-insensitive matching.
11. **Combining marks not attached** — orphan combining characters.
12. **RTL / bidi isolation** — mixed LTR/RTL text without proper bidi markers for display.

## Procedure

1. **Profile text columns** — list columns with `dtype == object` and sample values.
2. **Run the checks above** per column; aggregate counts of each issue category.
3. **Produce a report** `unicode_report.md`:
   - Per column: issues detected, counts, sample rows (masked if PII), severity.
   - Severity rubric: mismatched normalisation = high (silent joins break), mojibake = high (lossy), confusables = medium (often benign but can indicate spoofing), invisible chars = medium, cosmetic whitespace = low.
4. **Propose a remediation script** per column with:
   - `unicodedata.normalize('NFC', s)` (or the user's preferred form).
   - Strip invisible characters (whitelist of explicitly-allowed ones, remove the rest).
   - Replace non-breaking spaces with regular spaces (if appropriate).
   - Normalise quotes/dashes if the domain wants ASCII.
   - Fix known mojibake via `ftfy.fix_text(...)`.
5. **Preview on sample before applying** — show 10 before/after pairs and confirm with user.
6. **Apply to a new column** (`<col>_nfc` or `<col>_clean`) by default; overwrite only on explicit request — and follow the backup policy in `CONVENTIONS.md`.
7. **Re-run the audit** to confirm residual issues.
8. **Update the data dictionary** — record the normalisation form and cleaning rules applied per column.

## Dependencies

```bash
pip install pandas charset-normalizer ftfy
# optional
pip install confusable-homoglyphs
```

Python stdlib `unicodedata` covers most detection needs.

## Edge cases

- **Intentional script mixing** — multilingual datasets (e.g. Japanese text with Latin product codes) are expected. Whitelist allowed script combinations rather than flagging everything.
- **Domain-specific punctuation** — code columns (e.g. identifiers) may legitimately use non-ASCII; don't auto-normalise without user confirmation.
- **Round-trip-sensitive fields** — cryptographic hashes, signatures, URLs with percent-encoding — never normalise; flag as "do not touch".
- **ftfy limits** — `ftfy.fix_text` is heuristic and occasionally over-corrects. Preview before applying at scale.
- **Normalisation form downstream requirements** — HF Datasets / JSON-LD / web APIs typically want NFC; some linguistic tools want NFD. Ask before picking.

## Safety

Follow the backup policy in `CONVENTIONS.md` before any in-place mutation of text values.
