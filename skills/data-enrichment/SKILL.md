---
name: data-enrichment
description: Suggest and explore potential enrichment approaches for a dataset — identifying fields that could be augmented via public reference data, derived calculations, geospatial lookup, temporal decomposition, or third-party APIs. Use when the user wants ideas for making a dataset more analytically valuable but isn't sure what enrichments are feasible.
---

# Data Enrichment

Brainstorm and evaluate enrichment options for a dataset. Produces a menu of candidate enrichments with feasibility, cost, and value notes.

## When to invoke

- User asks "how could this dataset be enriched?" or "what could we add to make this more useful?".
- Dataset is already clean and the user is looking for next steps before analysis/modelling.

## Procedure

1. **Profile the dataset** — column list, types, null rates, sample values.
2. **Scan for enrichment-ready columns**:
   - **Geographic**: country / city / region / address / coordinates → ISO codes, currency, language, population, timezone, continent, GDP, coordinates (geocoding).
   - **Temporal**: date / datetime → year, quarter, month, day-of-week, week-of-year, is-weekend, is-holiday (country-specific), season, fiscal-year.
   - **Identifiers**: VAT / company number / stock ticker / ISBN / DOI / wiki-ID → metadata lookups via public APIs (Wikidata, OpenCorporates, yfinance, crossref).
   - **Monetary**: amount + currency + date → FX-normalised value, inflation-adjusted value, common-base conversion.
   - **Text**: free text → language detection, sentiment, entities, embeddings, topic labels.
   - **Email / domain**: → domain, MX records, company lookup (handle PII carefully — see `pii-flag`).
   - **IP address**: → geolocation, ASN, ISP.
3. **Emit an enrichment menu** — for each candidate enrichment, record:
   - **What** it adds (columns and types).
   - **Source** (in-plugin skill, public dataset, public API, paid API, LLM).
   - **Feasibility** (high / medium / low — notes on rate limits, cost, accuracy).
   - **Privacy / licensing considerations** — especially for third-party API outputs.
   - **Example output** — one row of synthetic enrichment on a sample input value.
4. **Rank by value × feasibility** — high-value / high-feasibility items first. Let the user pick.
5. **Link to executing skills** — some enrichments map to plugin skills (`add-iso3166`, `enrich-with-currency`); others need a bespoke one-off script which this skill can scaffold but not run without user confirmation.
6. **Write the menu** to `enrichment_options.md` alongside the dataset.

## Dependencies

```bash
pip install pandas
```

Plus optional per-enrichment libraries (flagged in the menu):
- `pycountry`, `babel` — geographic + currency.
- `holidays` — calendar-based enrichment.
- `geopy` — geocoding (respect usage policies).
- `wikidata` / `SPARQLWrapper` — entity enrichment.
- `yfinance` — market data.

## Edge cases

- **PII-heavy columns** — if the field looks like PII (see `pii-flag`), note the risk in the menu and recommend reviewing legality before enriching via third-party services.
- **Rate-limited APIs** — estimate request count and warn if it exceeds free-tier limits.
- **Low-accuracy enrichments** (fuzzy entity matching, sentiment) — mark accuracy explicitly; do not oversell.
- **Licence-restricted sources** — flag anything that would contaminate the dataset's own licence (e.g. adding Google Places data to a CC-BY dataset).
