#!/usr/bin/env bash
# install-deps.sh — provision a uv-managed virtualenv for Claude-Data-Wrangler.
#
# Creates (or reuses) a venv at .venv inside the plugin directory and
# installs every dependency listed in requirements.txt via uv.
#
# Usage:
#   ./scripts/install-deps.sh                 # install all dependencies
#   ./scripts/install-deps.sh --minimal       # install only the core tabular stack
#   ./scripts/install-deps.sh --group vector  # install a named group only
#   VENV_DIR=/tmp/cdw-venv ./scripts/install-deps.sh
#
# Groups: core, iso, dates, text, pii, enrichment, sql, vector, graph, api, hf
#
# uv docs: https://docs.astral.sh/uv/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_DIR="${VENV_DIR:-${REPO_DIR}/.venv}"

if ! command -v uv >/dev/null 2>&1; then
  echo "error: 'uv' is not installed or not on PATH." >&2
  echo "install with:  curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  echo "(or)           pipx install uv" >&2
  exit 1
fi

# Groups map — keep aligned with requirements.txt section comments.
declare -A GROUPS
GROUPS[core]="pandas pyarrow openpyxl"
GROUPS[iso]="pycountry babel langcodes iso4217 python-stdnum"
GROUPS[dates]="python-dateutil"
GROUPS[text]="charset-normalizer chardet ftfy confusable-homoglyphs"
GROUPS[pii]="phonenumbers presidio-analyzer presidio-anonymizer faker"
GROUPS[enrichment]="holidays"
GROUPS[sql]="SQLAlchemy psycopg[binary] PyMySQL pyodbc duckdb"
GROUPS[vector]="sentence-transformers pinecone-client qdrant-client weaviate-client pymilvus chromadb"
GROUPS[graph]="neo4j python-arango gqlalchemy"
GROUPS[api]="httpx tenacity prance openapi-spec-validator"
GROUPS[hf]="huggingface_hub"
GROUPS[misc]="PyYAML zstandard"

MODE="all"
GROUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --minimal) MODE="minimal"; shift ;;
    --group)   MODE="group"; GROUP="${2:-}"; shift 2 ;;
    --all)     MODE="all"; shift ;;
    -h|--help)
      sed -n '1,30p' "$0"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

echo ">> creating venv at ${VENV_DIR} (if missing)"
uv venv --quiet "${VENV_DIR}"

# Activate for nicer messaging; uv pip install targets --python implicitly via VIRTUAL_ENV.
# shellcheck disable=SC1090,SC1091
source "${VENV_DIR}/bin/activate"

case "$MODE" in
  all)
    echo ">> installing all dependencies from requirements.txt"
    uv pip install -r "${REPO_DIR}/requirements.txt"
    ;;
  minimal)
    echo ">> installing minimal (core + iso + dates + misc)"
    # shellcheck disable=SC2086
    uv pip install ${GROUPS[core]} ${GROUPS[iso]} ${GROUPS[dates]} ${GROUPS[misc]}
    ;;
  group)
    if [[ -z "$GROUP" || -z "${GROUPS[$GROUP]:-}" ]]; then
      echo "error: --group requires one of: ${!GROUPS[*]}" >&2
      exit 2
    fi
    echo ">> installing group: $GROUP"
    # shellcheck disable=SC2086
    uv pip install ${GROUPS[$GROUP]}
    ;;
esac

echo
echo "done. activate the venv with:"
echo "  source ${VENV_DIR}/bin/activate"
