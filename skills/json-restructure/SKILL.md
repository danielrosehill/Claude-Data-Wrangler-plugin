---
name: json-restructure
description: Restructure JSON or JSONL data — pivot flat records into nested hierarchy, un-nest deeply nested structures, group by keys, promote/demote fields in the hierarchy, split arrays into sibling objects. Use when JSON shape needs to change (e.g. flat rows → grouped-by-country nesting, or nested API response → flat table).
---

# JSON Restructuring

Reshape JSON/JSONL structure — nest, un-nest, pivot, group.

## When to invoke

- User wants to change the *shape* of JSON, not just the format.
- Examples: "group these rows by country", "flatten this nested API response", "turn this list of transactions into one object per account with transactions as a nested array".

## Common operations

### 1. Flatten (un-nest)

Input:
```json
{"user": {"id": 1, "profile": {"name": "Alice", "email": "a@x.com"}}}
```
Output (dotted keys):
```json
{"user.id": 1, "user.profile.name": "Alice", "user.profile.email": "a@x.com"}
```

### 2. Unflatten (nest)

Inverse of flatten — dotted keys → nested objects.

### 3. Group by key (pivot to hierarchy)

Input (flat rows):
```json
[{"country":"FR","city":"Paris","pop":2}, {"country":"FR","city":"Lyon","pop":0.5}, {"country":"DE","city":"Berlin","pop":3.6}]
```
Output (grouped):
```json
{"FR": [{"city":"Paris","pop":2},{"city":"Lyon","pop":0.5}], "DE": [{"city":"Berlin","pop":3.6}]}
```

### 4. Ungroup (hierarchy → flat rows)

Inverse of group-by — emit one row per leaf with the grouping keys promoted to columns.

### 5. Promote / demote fields

Move a field up or down in the hierarchy. E.g. promote `user.profile.email` to a top-level `email` field.

### 6. Array → siblings (explode)

Input: `{"id": 1, "tags": ["a", "b", "c"]}`
Output: three records, each with the `id` and one tag value (like pandas `explode`).

### 7. Siblings → array (collapse)

Inverse of explode.

## Procedure

1. **Inspect the current shape** — load a sample, print the structure (keys, nesting depth, array lengths).
2. **Confirm the target shape with the user** — describe it explicitly: top-level type (array / object), key structure, nesting depth. Draw a small example if complex.
3. **Pick the operation(s)** from the list above. Multi-step transformations are fine; sequence them.
4. **Prototype on a sample** (first 5 records) and show the user before running on the full file.
5. **Run the transformation**:
   - Small files: load fully with `json.load`.
   - Large files / JSONL: stream line by line.
   - Use `pandas.json_normalize` for flatten operations.
   - Group-by via `itertools.groupby` (sorted) or `collections.defaultdict`.
6. **Validate** — record counts, key coverage, round-trip sanity check when possible.
7. **Write output** with a descriptive suffix (`_grouped`, `_flat`, `_exploded`).
8. **Update the data dictionary** — structural changes deserve a provenance entry and potentially a new column/field list.

## Dependencies

```bash
pip install pandas
```

Standard library `json`, `collections`, `itertools` cover most cases.

## Edge cases

- **Conflicting keys during flatten** — e.g. two nested paths that collapse to the same dotted key. Report and ask user for disambiguation rule (suffix, error, keep-first).
- **Mixed types in grouped output** — when grouping, some groups may have arrays and some scalars. Normalise to always-array unless user requests otherwise.
- **Non-JSON-serialisable values** after transformation (datetimes, NaN, bytes) — convert to ISO strings / `null` / base64, and note in the data dictionary.
- **Key ordering** — JSON is unordered by spec but readers may care. Default to preserving input order; offer alphabetical sort as an option.
