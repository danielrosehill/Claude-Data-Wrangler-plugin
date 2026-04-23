# Claude-Data-Wrangler Conventions

All skills in this plugin follow the conventions in this file. Skill authors should reference it from individual SKILL.md files rather than duplicating rules.

## Safety: backup before destructive edits

**Before any skill performs an in-place or potentially destructive modification to a dataset, confirm a backup is in place.**

"Destructive" includes: overwriting the source file, deleting columns, mutating values in place, replacing PII with synthetic data, loading data to a remote store that the user could not later reconstruct from the file alone, any refactor that rewrites the original dataset.

### Required pre-flight for any destructive skill

1. **Ask the user**: "Is the source dataset already backed up or under version control?"
2. **If yes**, proceed after noting the backup location in the skill's report.
3. **If no or unsure**, offer (and by default perform) a backup before the destructive step:
   - **File copy** — `<original>.bak-<YYYYMMDD-HHMM>` alongside the source.
   - **Packaged snapshot** — via `parquet-jsonl-package`, producing Parquet + JSONL copies in a `backups/` subfolder with a timestamped name.
   - **Git snapshot** — if the dataset is in a git repo, offer to commit (or stash) first.
   Let the user pick; default to a simple file copy if they don't specify.
4. **Record the backup** in the data dictionary's provenance log and in the skill's report.
5. **Never skip this step silently.** If the user explicitly declines a backup, record that decision in the report and proceed.

### Non-destructive by default

Prefer to write outputs to a **new file** (with a suffix like `_iso3166`, `_numeric`, `_standardised`) rather than overwriting. Only overwrite when the user explicitly asks. Even then, backup first.

### Destructive beyond the file

Loading to a remote system (SQL DB, vector DB, graph DB, HF Hub, API) that creates a new shared state is not destructive to the source file but **is** a write that's hard to unwind. Same posture: confirm the user has the local dataset preserved, confirm idempotency or dry-run first, and never silently clobber an existing remote collection/index/table without explicit confirmation.

## Data storage (plugin data vs user-owned data)

- **User-owned data** (the datasets themselves) lives wherever the user chose — do not move it.
- **Plugin config / profiles** (SQL connection profiles, vector backend profiles, embedding defaults) lives in:

  ```
  ${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-plugins}/Claude-Data-Wrangler/
  ```

  with `config.json`, `data/`, `cache/`, `state/` subdirectories as needed.

- **Never** write plugin data into `~/.claude/plugins/Claude-Data-Wrangler/` (that's the install dir and is clobbered on updates) or into `~/.claude/` directly.

## Secrets

Never store API keys, database passwords, or tokens in plaintext in config files or datasets. Reference them via:
- Environment variables (`{"type": "env", "name": "PINECONE_API_KEY"}`).
- 1Password CLI (`{"type": "op", "reference": "op://Private/Service/api_key"}`).
- Prompt-at-runtime (`{"type": "prompt"}`).

## Data dictionary as single source of truth

Every schema-changing operation updates the dataset's data dictionary (creating one via `add-data-dictionary` if absent). Provenance entries should be dated and identify the skill that ran.

## Reporting

Each skill writes a short text report alongside the dataset summarising what ran, what changed, what was skipped, and any residual issues — so the user has a paper trail without re-running the skill to remember.
