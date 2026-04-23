---
name: data-shape
description: Advise on how to reshape a dataset for logical storage in a database — normalisation decisions, splitting denormalised rows into related tables, extracting repeating groups, separating dimensions from facts, promoting nested structures to joinable tables, and proposing a schema. Use when the user is preparing data that hasn't been stored yet (or needs to be re-stored) and wants guidance on the right shape before loading.
---

# Data Shape

Propose a schema (tables, keys, relationships) that will give the dataset a logical home in SQL (or another structured system).

## When to invoke

- Data is still in flat files / API dumps / spreadsheets and hasn't been loaded to a database.
- The current shape is denormalised, wide, or contains repeating/semi-structured content.
- User says "how should I structure this before loading?", "is this normalised?", "what tables should I have?".

## Procedure

1. **Profile the source** — columns, types, cardinalities, null rates, sample rows.
2. **Detect shape smells**:
   - **Repeating column groups** — `item_1_name`, `item_1_qty`, `item_2_name`, `item_2_qty`, ... → candidate for a child table.
   - **Packed fields** — comma-separated tags, JSON stuffed into a single column → candidate for a junction table or a proper nested type.
   - **Redundant reference data** — `country`, `country_code`, `country_population`, `country_gdp` co-located with transactional rows → candidate dimension table.
   - **Slowly changing attributes** — entity descriptors that change over time (status, tier) mixed with events → candidate for SCD Type 2 or separate event table.
   - **Mixed grain** — summary rows mixed with detail rows in the same table.
   - **Natural composite keys** — uniqueness only holds across multiple columns.
3. **Propose a target schema**:
   - **Entities** (dimensions / master data): one table per entity, stable primary key, attributes that describe the entity.
   - **Events / facts**: one table per event type, foreign keys to entities, timestamp column, measure columns.
   - **Junction tables** for many-to-many relationships.
   - **Lookup / enum tables** for low-cardinality categorical fields (optional; natural strings are fine if the DB supports `ENUM` or CHECK constraints).
   - **Keys**: surrogate (auto-increment / UUID) vs natural; recommend per table with rationale.
   - **Indexes**: primary key, foreign keys, and query-driven indexes based on expected access patterns.
4. **Normalisation level** — usually target 3NF for transactional, then consider selective denormalisation (materialised views, wide reporting tables) for analytics.
5. **Star-schema / snowflake** option — for analytical workloads, propose fact + dimension layout.
6. **Produce artefacts**:
   - `schema_proposal.md` — prose rationale + ER diagram sketch (Mermaid).
   - `schema.sql` — `CREATE TABLE` statements ready to run (or adapt).
   - Mapping from source columns to target columns (for the subsequent load step).
7. **Link to executors** — the schema is ready for `sql-load` once the user has transformed the source into the proposed per-table shape. Graph shape → `graph-database`; vector shape → `vector-upsert`.

## Dependencies

```bash
pip install pandas
```

## Edge cases

- **Denormalised intentionally** (e.g. analytical wide tables) — ask the user about the workload before recommending normalisation.
- **Semi-structured fields that should stay semi-structured** (e.g. raw API payloads kept for audit) — use JSONB / JSON columns rather than forcing flattening.
- **Surrogate-key debates** — offer the trade-offs (natural keys expose meaning but change; surrogates are stable but require joins) and let the user pick.
- **Historical data + SCD** — if the user needs point-in-time queries, recommend SCD Type 2 (valid-from / valid-to) or separate snapshot tables.
