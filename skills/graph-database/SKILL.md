---
name: graph-database
description: Transform existing tabular or JSON data into a graph-suitable representation (nodes, edges, properties) and emit it for a graph database (Neo4j, ArangoDB, Memgraph, Postgres + Apache AGE). Identifies candidate node types and edge relationships, produces Cypher (or GraphML / CSV bulk-load) output, and optionally loads directly. Use when the user wants to model a dataset as a graph.
---

# Graph Database

Reshape tabular/JSON data into graph form and emit loadable artefacts.

## When to invoke

- User says "make this a graph", "load into Neo4j", "model as nodes and edges".
- Dataset has obvious relationship structure (people → companies, papers → authors → citations, transactions → accounts).
- `database-guide` recommended a graph backend.

## Procedure

1. **Profile the data** — columns, cardinalities, foreign-key-like relationships.
2. **Identify node types**:
   - Distinct entities (rows in dimension-like tables).
   - Columns with identifier semantics (`user_id`, `company_id`, `paper_doi`).
   - Categorical columns with meaningful entity-like values (e.g. `country`).
3. **Identify edge types**:
   - Explicit foreign keys (`user_id` in an `orders` row implies `User`—[PLACED]→`Order`).
   - Many-to-many junction tables (`paper_authors` → `Paper`—[AUTHORED_BY]→`Author`).
   - Co-occurrence / shared attributes (optional, can explode the graph — ask first).
   - Temporal sequencing (events linked by `next_event`).
4. **Propose a graph schema**:
   - Label per node type, with a primary property that uniquely identifies the node.
   - Relationship type(s) with direction and properties (e.g. `date`, `weight`).
   - List of node properties vs edge properties (be thrifty with edge properties).
5. **Confirm the schema with the user** with an example subgraph (Mermaid or plain ASCII).
6. **Emit artefacts** (pick one or more based on target platform):
   - **Neo4j**: Cypher `CREATE` / `MERGE` statements in a `.cypher` file. For bulk loads, emit `nodes.csv` + `relationships.csv` matching `neo4j-admin database import` conventions.
   - **ArangoDB**: JSON collections (documents) + edge collection JSON.
   - **Memgraph**: same Cypher as Neo4j (compatible).
   - **Postgres + Apache AGE**: Cypher via `ag_catalog`, or plain tables + a SQL view.
   - **Generic**: GraphML XML, or a portable JSON format (`{nodes: [...], edges: [...]}`).
7. **Optionally load** — if the user has credentials and the DB is reachable, run the load and verify counts (`MATCH (n) RETURN count(n)` per label).
8. **Report** — node counts per label, edge counts per type, and a sample 2-hop query to validate connectivity.

## Dependencies

```bash
pip install pandas
# target-specific
pip install neo4j            # Neo4j driver
pip install python-arango    # ArangoDB driver
pip install gqlalchemy       # Memgraph driver
```

## Edge cases

- **No natural IDs** — generate surrogate IDs (hash of natural attributes, or UUIDs). Record the generator in the data dictionary so re-runs are deterministic.
- **Very dense relationships** (every node connects to every other) — graph DBs aren't magic; warn the user about query performance for hub nodes and suggest modelling tweaks.
- **Properties that should be nodes** — e.g. `tags` as a string array on papers. Decide per case whether `Tag` deserves node-hood (yes if you'll query *"papers with tag X"*, no if tags are always read as a list).
- **Temporal data** — pure graph DBs handle time poorly; either add `valid_from` / `valid_to` properties, model time as nodes, or keep a time-series store alongside.
- **Large bulk loads** — prefer CSV bulk import over row-by-row Cypher for >1M rows (orders of magnitude faster on Neo4j).
