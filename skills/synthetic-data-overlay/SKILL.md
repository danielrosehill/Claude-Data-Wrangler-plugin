---
name: synthetic-data-overlay
description: Replace PII (or other sensitive values) in a dataset with synthetic but realistic substitutes, preserving statistical shape, formats, and referential integrity where needed. Use after pii-flag has identified sensitive cells and the user wants the dataset anonymised but still analytically usable.
---

# Synthetic Data Overlay

Replace sensitive values with synthetic ones that preserve shape and joinability.

## When to invoke

- `pii-flag` has produced a report and the user wants remediation by substitution (rather than drop or hash).
- User wants to share or publish a dataset while preserving analytical structure.

## Strategies

Choose per column based on the kind of data:

| Category | Strategy |
|---|---|
| Names | Generate synthetic names via Faker (locale-matched if possible). |
| Emails | Synthetic email using generated name + fake domain (`@example.com`). |
| Phone numbers | Faker generator with country locale matching the original. |
| Addresses | Faker address; preserve country/city-level granularity if needed for analysis. |
| Dates of birth | Shift by a random offset (per-row or constant), OR bucket to age range and resample. |
| Government IDs | Generate format-valid but non-real IDs (e.g. valid checksum, clearly-fake prefix). |
| Credit cards | Use PAN test ranges (e.g. `4111-1111-...`) which are Luhn-valid but publicly known as test numbers. |
| Geocoordinates | Add uniform noise within a radius (e.g. ±500m) OR snap to city centroid. |
| Free text with PII | Presidio-anonymizer with per-entity strategies. |
| Arbitrary categorical | Sample from original distribution (preserves frequencies) or a uniform placeholder. |
| Numerical (non-PII but sensitive) | Add calibrated noise or use synthetic generation libraries (`sdv`, `synthcity`). |

## Procedure

1. **Require a PII report** as input (from `pii-flag`). Do not re-detect from scratch here.
2. **Present the strategy plan** per flagged column, including a preview of 3 synthetic replacements alongside the originals (masked). Confirm with the user before applying.
3. **Preserve referential integrity**:
   - Same original value → same synthetic value across rows AND across related files (use a deterministic seeded mapping, keep the mapping out of the output).
   - Cross-column consistency (name ↔ email ↔ phone): generate as a coherent persona, not independently.
4. **Apply replacements** and write the overlay output with `_synthetic` suffix. The original file is never modified.
5. **Destroy the mapping** between real and synthetic values by default, OR store it encrypted outside the dataset folder with a user-confirmed path. Never commit the mapping to the dataset's git repo.
6. **Re-run `pii-flag`** on the output as a verification step. Report residual findings.
7. **Update the data dictionary** — record which columns were synthesised and the strategy used. Mark the dataset as "synthetic overlay applied" in provenance.
8. **Refuse to push synthetic datasets as real** — if the user subsequently invokes `hf-dataset-push`, ensure the dataset card marks the data as synthetic-overlaid with a clear disclaimer.

## Dependencies

```bash
pip install pandas faker
# optional
pip install presidio-anonymizer sdv synthcity
```

## Edge cases

- **Statistical fidelity matters** — if the downstream use is modelling, random sampling from a uniform distribution will distort results. Prefer distribution-preserving methods (`sdv` CTGAN, sampling from the original distribution) and document the chosen approach.
- **Locale mismatch** — don't generate US-style phone numbers for Israeli data. Use locale-aware Faker instances per row.
- **Re-identification risk** — even synthetic overlays can leak information if quasi-identifiers (age + city + profession) uniquely identify individuals. Warn the user and recommend k-anonymity checks for high-risk datasets.
- **Free-text residue** — PII in long-form text is hard to fully scrub; note residual risk explicitly.
