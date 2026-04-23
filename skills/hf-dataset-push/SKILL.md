---
name: hf-dataset-push
description: Push a prepared dataset to Hugging Face Hub as a Dataset repository, with dataset card (README.md), config, and data files (Parquet / JSONL / CSV). Use after the dataset is cleaned and packaged (ideally via the parquet-jsonl-package skill) and the user wants it published on HF.
---

# Hugging Face Dataset Push

Publish a dataset to `huggingface.co/datasets/<user-or-org>/<name>`.

## When to invoke

- User asks to "push to Hugging Face", "publish dataset to HF", "upload to the Hub".
- Dataset is already cleaned, documented (data dictionary), and packaged (Parquet / JSONL / CSV).

## Prerequisites

- Hugging Face account and username (or org).
- Authenticated CLI: `hf auth login` (or `huggingface-cli login` on older versions) — if not authenticated, stop and instruct the user to log in. Do **not** prompt for or store tokens.
- Packaged files ready — if only raw CSV exists, suggest running `parquet-jsonl-package` first for better HF Datasets integration.

## Procedure

1. **Gather metadata from the user**:
   - Repo name (kebab-case on HF).
   - Namespace: personal user or org.
   - Visibility: public or private.
   - License (SPDX identifier — e.g. `mit`, `apache-2.0`, `cc-by-4.0`, `cc0-1.0`).
   - Task tags (e.g. `text-classification`, `tabular-classification`, `question-answering`).
   - Language(s) if applicable.
   - Size category (auto-infer from row count: `n<1K`, `1K<n<10K`, `10K<n<100K`, `100K<n<1M`, `1M<n<10M`, `n>10M`).
2. **Generate the dataset card** (`README.md`) with YAML frontmatter:
   ```yaml
   ---
   license: <spdx>
   task_categories:
     - <task>
   language:
     - en
   size_categories:
     - 10K<n<100K
   tags:
     - <tag>
   ---
   ```
   Followed by sections: Description, Source, Data fields (copied from the data dictionary), Splits (if any), Preprocessing / provenance (from the data dictionary transformations log), Licensing, Citation.
3. **Organise files**:
   - Root: `README.md` (dataset card), `data_dictionary.md` (copy of the data dictionary).
   - `data/` folder: `train.parquet` / `test.parquet` / `validation.parquet` if the user has splits — otherwise a single `data.parquet` or `data.jsonl`.
   - If using HF's auto-detection for splits, name files by split pattern (`train-*.parquet`).
4. **Create the repo**:
   ```bash
   hf repo create <namespace>/<name> --type dataset [--private]
   ```
5. **Upload files** using `hf upload` (preferred) or `huggingface_hub.HfApi().upload_folder(...)`:
   ```bash
   hf upload <namespace>/<name> ./local-folder --repo-type dataset
   ```
   For large files, `hf upload-large-folder` handles resumable multi-part uploads.
6. **Verify** — fetch the repo page, confirm files are listed, dataset card renders, and the "Dataset Preview" loads. If preview fails, inspect schema and file naming.
7. **Report** the dataset URL to the user.

## Dependencies

```bash
pip install huggingface_hub
# The `hf` CLI is installed with huggingface_hub >= 0.24. Older installs use `huggingface-cli`.
```

## Edge cases

- **Not authenticated** — stop and tell the user to run `hf auth login`. Do not handle tokens in code.
- **Private dataset with org** — confirm the user has write permission to the org.
- **Files > 5 GB** — use `hf upload-large-folder` or enable LFS via `hf lfs` configuration.
- **Dataset already exists** — ask whether to push a new revision (commit), create a new branch, or abort. Do not force-push without explicit confirmation.
- **Sensitive data** — before upload, verify with the user that no PII / credentials / private information is included. Public HF datasets are crawled and indexed.
- **License mismatch** — if the source data has a license that restricts redistribution, warn the user and confirm before proceeding.
