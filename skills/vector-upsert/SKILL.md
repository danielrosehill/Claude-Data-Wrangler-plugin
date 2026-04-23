---
name: vector-upsert
description: Build a pipeline that takes the current working dataset, embeds the relevant text/fields, and upserts into a configured vector database backend (Pinecone, Qdrant, Weaviate, Milvus, pgvector, ChromaDB). Handles embedding model selection, chunking for long text, metadata attachment, namespace/collection management, and idempotent upserts. Use when the user wants to make a dataset semantically searchable.
---

# Vector Upsert

End-to-end pipeline: dataset → embeddings → vector DB upsert.

## When to invoke

- User wants semantic search over their data.
- `database-guide` recommended a vector backend.
- Existing embeddings need to be refreshed.

## Supported backends

- **Pinecone** (managed cloud).
- **Qdrant** (self-hosted or cloud).
- **Weaviate** (self-hosted or cloud).
- **Milvus / Zilliz**.
- **pgvector** (Postgres extension).
- **ChromaDB** (local / embedded).

## Procedure

1. **Identify the source** — dataset path and the column(s) to embed.
2. **Pick the embedding model**:
   - **Local** (no API cost): `sentence-transformers` (e.g. `all-MiniLM-L6-v2`, `BAAI/bge-small-en-v1.5`) or a task-tuned model.
   - **Hosted**: OpenAI `text-embedding-3-small` / `-large`; Cohere; Voyage; Jina; Anthropic-compatible via wrappers.
   - Default to a small local model unless the user wants hosted quality; record the choice in the data dictionary.
3. **Chunk if needed**:
   - Detect long text (>token budget of the chosen model).
   - Chunk by sentence boundaries with overlap (default 400 tokens, 50 overlap). Confirm with user.
   - Track `chunk_id` and `parent_row_id` so downstream search can re-aggregate.
4. **Attach metadata** — every vector carries payload metadata for filtering. Ask the user which columns to include (keep small; vector DBs aren't the place for big blobs).
5. **Configure the target**:
   - **Existing config**: look in `$CLAUDE_USER_DATA/Claude-Data-Wrangler/config.json` under `vector_profiles` for saved backends.
   - **New config**: ask for backend, endpoint/URL, index/collection name, API key reference (env var / 1Password / prompt — never plaintext).
   - Create the index/collection if missing, with the correct vector dimension for the chosen model and a distance metric (cosine by default).
6. **Embed in batches** (default 64 rows per batch) with retries on rate limits / transient errors.
7. **Upsert** with deterministic IDs (hash of `parent_row_id + chunk_id`) so re-runs are idempotent.
8. **Verify** — fetch a known ID back; run a sample query and sanity-check results.
9. **Report** — vectors embedded, upserted count, backend index stats, and a sample search.
10. **Update the data dictionary** with the embedding model, dimension, chunk params, and target index name.

## Config file structure

`$CLAUDE_USER_DATA/Claude-Data-Wrangler/config.json`:

```json
{
  "vector_profiles": {
    "pinecone-prod": {
      "backend": "pinecone",
      "index": "knowledge-base",
      "namespace": "documents",
      "api_key_ref": {"type": "op", "reference": "op://Private/Pinecone/api_key"}
    },
    "local-qdrant": {
      "backend": "qdrant",
      "url": "http://localhost:6333",
      "collection": "documents"
    }
  },
  "embedding_defaults": {
    "model": "BAAI/bge-small-en-v1.5",
    "dimension": 384,
    "metric": "cosine"
  }
}
```

## Dependencies

```bash
pip install pandas sentence-transformers  # local embedding
# per backend
pip install pinecone-client
pip install qdrant-client
pip install weaviate-client
pip install pymilvus
pip install psycopg[binary]  # for pgvector
pip install chromadb
```

## Edge cases

- **Dimension mismatch** — if the configured index has a different dimension from the chosen model, refuse to upsert and recommend either switching model or creating a new index. Do not auto-reshape vectors.
- **Rate limits on hosted embedding** — batch with backoff; estimate cost upfront for large datasets and confirm with user.
- **Idempotency + updates** — deterministic IDs mean re-running over the same data overwrites in place. If the user wants history, recommend a separate "versioned" index or include a `version` field in metadata.
- **Multilingual content** — pick a multilingual model (`paraphrase-multilingual-mpnet-base-v2`, `multilingual-e5-large`); don't silently embed non-English with an English-only model.
- **PII in embedded text** — run `pii-flag` first; embeddings can leak training-adjacent info and are hard to redact after the fact.
