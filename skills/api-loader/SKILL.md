---
name: api-loader
description: Prepare or refactor a dataset for upload into a REST API or MCP server — mapping dataset columns to API request fields, handling batching, pagination, rate limits, authentication, idempotency, and error retries. Works from an OpenAPI spec the user provides, a user-pointed MCP tool schema, or documentation for a well-known API (Salesforce, HubSpot, Airtable, Notion, Stripe, Shopify, Pipedrive, etc.). Generates a loader script plus a dry-run preview before executing.
---

# API Loader

Ingest a cleaned dataset into a target API or MCP server.

## When to invoke

- User has a dataset and wants to push it into a system whose interface is an HTTP API (CRM, ticketing, marketing, payments, data platform).
- User has an MCP server whose tools they want to call in bulk from a dataset.
- User asks: "load this into Salesforce", "push to HubSpot", "bulk-create records via this API", "call this MCP tool for each row".

## Inputs to gather

1. **Target interface type**:
   - **OpenAPI / Swagger spec** — user provides URL or file. Parse with `openapi-spec-validator` + `openapi-schema-pydantic` or `prance`.
   - **MCP server** — user provides the server name; inspect available tools and their JSON Schema inputs via the MCP listing.
   - **Well-known API** — use documented endpoints for Salesforce, HubSpot, Airtable, Notion, Stripe, Shopify, Pipedrive, Zendesk, Jira, GitHub, GitLab, Linear. Always prefer fetching current docs via the Context7 MCP rather than relying on training data.
2. **Operation** — create / update / upsert / delete / invoke-tool. Which endpoint or tool specifically.
3. **Dataset** — path and shape; which columns will supply which API fields.
4. **Auth** — how credentials are provided (env var / 1Password / prompt). Never accept plaintext credentials in the conversation.
5. **Volume and rate constraints** — how many records; known rate limits (from the spec or docs).

## Procedure

1. **Load and validate the interface definition**:
   - OpenAPI: parse, list candidate endpoints, show parameter / body schemas for the chosen one.
   - MCP: list tools, fetch input schema for the chosen tool.
   - Well-known API: pull current docs via Context7; extract the endpoint shape.
2. **Produce a field mapping**:
   - Auto-suggest column → field mappings by name similarity and type compatibility.
   - Confirm each mapping with the user before proceeding.
   - Flag required fields with no source column (user must supply a default or abort).
   - Flag lossy conversions (string → enum, float → int).
3. **Transformation plan** — what cleaning / reshaping each column needs before it matches the API schema. Route to plugin skills where applicable (`text-to-numeric`, `date-wrangling`, `standardise-country-names`, `unicode-consistency`).
4. **Idempotency strategy**:
   - Prefer upsert endpoints with a natural-key uniqueness constraint.
   - If only create is available, compute a deterministic client-side ID (hash of stable columns) and store it in a local ledger to skip duplicates on retry.
   - Maintain a `load_ledger.jsonl` alongside the dataset recording `{row_id, request_hash, response_id, status, timestamp}`.
5. **Rate limiting and batching**:
   - Detect batch endpoints (`/bulk`, `/batch`) and prefer them.
   - Respect documented rate limits; default to 1 req/sec unless the spec / docs allow more.
   - Use exponential backoff on 429 / 5xx with `Retry-After` honoured when present.
6. **Dry-run first**:
   - Render 3 sample requests exactly as they would be sent (redact auth). Show the user.
   - Offer a "dry-run against the API" mode that hits a sandbox / `/validate` endpoint if available.
   - Require explicit confirmation before the real run.
7. **Execute the load** — stream rows, call the endpoint / MCP tool per row (or per batch), append to the ledger after each success/failure.
8. **Report**:
   - Success count, failure count by error class, retry count.
   - Failing rows with the error messages, in `api_load_failures.jsonl`.
   - Offer to retry only the failed rows.
9. **Update the data dictionary** — mark which columns were loaded, target endpoint / tool, date, and the ledger file name.

## Config file structure

`$CLAUDE_USER_DATA/Claude-Data-Wrangler/config.json`:

```json
{
  "api_profiles": {
    "salesforce-prod": {
      "kind": "well-known",
      "service": "salesforce",
      "instance_url": "https://example.my.salesforce.com",
      "auth": {
        "type": "oauth2_refresh",
        "client_id_ref": {"type": "op", "reference": "op://Private/SF/client_id"},
        "client_secret_ref": {"type": "op", "reference": "op://Private/SF/client_secret"},
        "refresh_token_ref": {"type": "op", "reference": "op://Private/SF/refresh_token"}
      }
    },
    "custom-api": {
      "kind": "openapi",
      "spec_url": "https://api.example.com/openapi.json",
      "base_url": "https://api.example.com",
      "auth": {"type": "bearer", "token_ref": {"type": "env", "name": "EXAMPLE_TOKEN"}}
    },
    "my-mcp": {
      "kind": "mcp",
      "server": "my-company-mcp"
    }
  }
}
```

## Dependencies

```bash
pip install pandas httpx tenacity
# OpenAPI handling
pip install prance openapi-spec-validator
# per well-known service (examples)
pip install simple-salesforce
pip install hubspot-api-client
pip install pyairtable
pip install notion-client
pip install stripe
pip install ShopifyAPI
```

Prefer official SDKs over hand-rolled HTTP where they exist and are stable.

## Edge cases

- **Schema evolution** between OpenAPI spec download and actual API — detect on first response mismatch; stop and report.
- **Partial failures in a batch** — many batch endpoints return per-record results; parse them and record success/failure per row, not per batch.
- **Sensitive fields** — run `pii-flag` before sending. Confirm with the user that the target is authorised to hold this data.
- **Quota costs** — some APIs (Salesforce bulk, Shopify admin) have per-day or per-hour caps that can be consumed faster than rate limit suggests. Estimate upfront.
- **MCP tools with ambiguous success semantics** — some tools return text rather than structured success. Parse carefully; when in doubt, surface raw output in the ledger and let the user judge.
- **Destructive operations** (delete, overwrite): treat as destructive per `CONVENTIONS.md` — require explicit confirmation, prefer soft-delete flags where available.

## Safety

API loads are writes to shared external state. Follow the backup policy in `CONVENTIONS.md`:
- Confirm the source dataset is backed up.
- Dry-run first — always.
- Prefer idempotent / upsert endpoints with deterministic client-side IDs, so a re-run doesn't double-insert.
- Never execute a destructive operation (delete, hard-overwrite) without a second explicit confirmation.
