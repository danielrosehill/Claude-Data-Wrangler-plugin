---
name: add-changelog
description: Add or update a CHANGELOG.md in a data repository, recording dataset versions, schema changes, row-count deltas, enrichments applied, and re-publications. Follows Keep-a-Changelog conventions adapted for datasets. Use when the user wants versioned documentation of how a dataset has evolved over time.
---

# Add Changelog (for Data Repositories)

Maintain a `CHANGELOG.md` focused on dataset evolution rather than code.

## When to invoke

- Data repository has no changelog and the user wants one.
- After any skill that changes dataset content or schema (enrichment, cleaning, synthetic overlay, republication) and the user wants a log entry added.

## Format

Adapted from [Keep a Changelog](https://keepachangelog.com), with dataset-specific sections:

```markdown
# Changelog

All notable changes to this dataset are documented here.
This format is adapted from Keep a Changelog; versions follow SemVer-ish rules:
- MAJOR: breaking schema or semantic changes (column removed/renamed, unit change).
- MINOR: new columns, new rows, compatible enrichments.
- PATCH: fixes to existing values, documentation updates, no schema change.

## [Unreleased]

## [1.2.0] — 2026-04-23
### Added
- `currency_code`, `currency_symbol` columns via `enrich-with-currency` (ISO 4217).
- 1,204 new rows from 2026-Q1 source pull.

### Changed
- `revenue` column parsed from text to numeric; original preserved as `revenue_raw`.
- Country names standardised to ISO 3166 short names.

### Fixed
- 17 rows with `country = "USA"` corrected to "United States".

### Provenance
- Skills used: `standardise-country-names`, `add-iso3166`, `enrich-with-currency`, `text-to-numeric`.
- Data dictionary updated: 2026-04-23.

## [1.1.0] — 2026-03-15
...
```

## Procedure

1. **Find or create `CHANGELOG.md`** in the data repository root.
2. **Determine the current version** — from the most recent versioned heading, or from a `VERSION` file if present. If none, start at `1.0.0`.
3. **Classify the change** — Added / Changed / Fixed / Removed / Deprecated / Security.
4. **Infer the version bump**:
   - Schema breaking → MAJOR.
   - New columns / new rows / enrichments → MINOR.
   - Value fixes / doc updates → PATCH.
   Confirm with the user before applying.
5. **Draft the entry** — pull context from the data dictionary provenance log if available, and the git diff if the repository is under version control.
6. **Insert at the top** under `## [Unreleased]`, or promote `Unreleased` to a new version with today's date.
7. **Write back** the updated changelog.
8. **Optionally tag** — offer to create a git tag (`v1.2.0`) and push it if the repo has a remote.

## Dependencies

Standard library only.

## Edge cases

- **First-time changelog** — produce a reasonable `[1.0.0]` baseline entry describing the dataset's initial state.
- **Concurrent edits** — if an `[Unreleased]` section already has pending entries, append rather than overwrite.
- **Non-git repo** — skip the tag step silently; just write the file.
- **Multi-dataset repo** — if the repo holds multiple datasets, scope entries per dataset name (e.g. `### [customers] Added`). Ask the user which dataset the change applies to.
