---
name: database-guide
description: Analyse the user's dataset (structure, volume, relationships, query patterns, access latency needs) and recommend the most suitable database system — relational (Postgres, MySQL, SQLite), analytical (DuckDB, ClickHouse, BigQuery), document (MongoDB), key-value (Redis, DynamoDB), graph (Neo4j), vector (Pinecone, pgvector, Qdrant, Weaviate), or time-series (InfluxDB, TimescaleDB). Produces a ranked recommendation with rationale. Use when the user is choosing where to store a new dataset.
---

# Database Guide

Recommend a database backend based on dataset shape, volume, and intended use.

## When to invoke

- User has raw data (flat files, API dumps) and hasn't yet picked a storage system.
- User asks "what database should I use?", "Postgres or Mongo?", "should this go in a graph DB?".
- Existing storage is painful and they want a second opinion.

## Inputs to gather

1. **Dataset description** — what it represents, row/record count, expected growth rate.
2. **Shape** — tabular (single or multiple related tables), document-like (nested JSON), time-series, graph-like (entities + relationships), text-heavy (for semantic search), mixed.
3. **Query patterns** — OLTP (many small reads/writes), OLAP (scans/aggregations on wide columns), lookups by key, similarity search, graph traversal, full-text search.
4. **Consistency / transactions** — does the workload need ACID? Multi-row transactions?
5. **Latency / throughput** — single-digit ms per query? Batch analytics OK? Concurrent users?
6. **Scale horizon** — MB, GB, TB, PB?
7. **Hosting preference** — self-hosted, managed cloud, serverless, file-based local?
8. **Budget** — free/OSS-only, willing to pay for managed, already in a cloud ecosystem (AWS/GCP/Azure/Cloudflare)?

## Candidate backends

| Category | Options | Fits when |
|---|---|---|
| Relational (OLTP) | PostgreSQL, MySQL/MariaDB, SQLite | Structured, normalised, transactional; <100GB hot; SQL is the query language |
| Analytical (OLAP) | DuckDB, ClickHouse, BigQuery, Snowflake, Redshift | Wide tables, heavy aggregations, append-mostly, columnar compression wins |
| Document | MongoDB, Couchbase, Firestore | Heterogeneous nested documents, schema-on-read, developer ergonomics |
| Key-value / wide-column | Redis, DynamoDB, Cassandra | Known-key lookups, very high throughput, simple shape |
| Graph | Neo4j, ArangoDB, Memgraph, Postgres + Apache AGE | Relationship traversal is the dominant query (k-hop, shortest path) |
| Vector | pgvector, Qdrant, Pinecone, Weaviate, Milvus | Similarity / semantic search on embeddings |
| Time-series | TimescaleDB, InfluxDB, QuestDB | High-cardinality timestamped metrics / events, downsampling, retention |
| Search | Elasticsearch, OpenSearch, Meilisearch, Typesense | Full-text search, faceting, analyzer pipelines |
| Hybrid starter | PostgreSQL + extensions (pgvector, PostGIS, TimescaleDB, AGE) | "One DB to rule them all" for small teams; defer specialisation |

## Procedure

1. **Profile the dataset** — shape, size, sample records, apparent relationships, nesting depth.
2. **Interview the user** if any of the inputs above are unclear. Don't guess the workload.
3. **Eliminate obviously wrong options** based on shape + workload.
4. **Rank the remaining 2–4 candidates** with:
   - Fit score (how well it matches shape + workload).
   - Operational cost (self-hosting effort, managed pricing).
   - Ecosystem fit (existing tooling, language bindings, cloud lock-in).
   - Scaling ceiling.
   - Risks / gotchas specific to this workload.
5. **Pick a recommendation** plus a runner-up. If Postgres-with-extensions covers the need, prefer it unless there's a clear specialisation payoff.
6. **Sketch a migration path** — how would the user actually load this data? Link to `sql-load` (for relational), `vector-upsert` (for vector), `graph-database` (for graph), and note analogous steps for other backends.
7. **Write the recommendation** to `database_recommendation.md` alongside the dataset.

## Dependencies

Standard library; pandas / pyarrow for profiling.

## Edge cases

- **"It depends" answers** — don't dodge. If two options are close, say so and give a tiebreaker (e.g. "pick Postgres if you value ecosystem, pick DuckDB if this is analytics-only and stays on one machine").
- **Polyglot persistence** temptation — flag when the user seems to want 3+ DBs and check if a single-DB solution would suffice.
- **Rapidly changing requirements** — if the user isn't sure of the workload, recommend Postgres-with-extensions as a safe default and revisit later.
- **Regulatory constraints** (data residency, encryption at rest, audit logging) — factor into hosting/managed decisions.
