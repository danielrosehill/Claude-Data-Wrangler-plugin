---
name: geodata-formatter
description: Convert tabular geodata (CSV / Excel / Parquet) into GeoJSON (or GeoJSON Seq / newline-delimited GeoJSON) — inferring geometry from lat/lon columns, WKT/WKB columns, or address columns via geocoding. Handles CRS reprojection (default WGS84 / EPSG:4326), feature property selection, and large-file streaming. Use when the user has location data in flat form and needs it as GeoJSON for mapping, GIS, or geospatial analysis tools.
---

# Geodata Formatter

Convert CSV / tabular geodata to GeoJSON.

## When to invoke

- User has a flat file with location columns and needs GeoJSON for Leaflet / Mapbox / QGIS / ArcGIS / Kepler.gl / geopandas / PostGIS.
- User asks "convert to GeoJSON", "make this mappable", "export as geojson".

## Supported inputs

1. **Lat/lon columns** — pair of numeric columns (`lat`/`lng`, `latitude`/`longitude`, `y`/`x`). Most common.
2. **WKT / WKB geometry column** — a string column containing `POINT(...)`, `LINESTRING(...)`, `POLYGON(...)` etc. (or hex-encoded WKB).
3. **H3 / S2 / geohash** — spatial index strings that decode to polygons/cells.
4. **Address / place name columns** — requires geocoding; ask user explicitly before using a third-party service and respect rate limits.

## Output formats

- **GeoJSON FeatureCollection** (`.geojson`) — single document, good for small/medium datasets.
- **GeoJSON Sequence / NDGeoJSON** (`.geojsonl` or `.geojsons`) — newline-delimited, good for streaming and >100k features.
- Optional: **TopoJSON** via `topojson` / `pytopojson` for compactness.
- Optional: **GeoParquet** (recommended for big data; a different skill, but link).

## Procedure

1. **Identify geometry source columns** — lat/lon pair, WKT, geohash, H3, or address. Ask if ambiguous.
2. **Confirm CRS**:
   - Default: EPSG:4326 (WGS84) — required by the GeoJSON spec (RFC 7946).
   - If the source is in a different CRS (e.g. British National Grid EPSG:27700, Web Mercator EPSG:3857, Israeli ITM EPSG:2039), reproject via `pyproj` before writing GeoJSON.
3. **Validate coordinate sanity**:
   - Lat in [-90, 90], lon in [-180, 180].
   - Flag rows outside these bounds — often indicates swapped lat/lon. Ask user.
   - NaN / null geometries → emit as `{"geometry": null, ...}` Features (valid per spec) or drop; ask user.
4. **Pick feature properties** — which columns become `properties` in each Feature. Default all non-geometry columns. Exclude PII-flagged columns by default.
5. **Build Features**:
   - Point: `{"type":"Point","coordinates":[lon,lat]}` — note the lon-first ordering (GeoJSON spec), not lat-first.
   - From WKT: parse with `shapely.wkt.loads` → `shapely.geometry.mapping(...)`.
   - From H3: decode to cell polygon via `h3.cells_to_geo([cell])`.
   - From address: geocode via `geopy` with a user-selected provider (Nominatim, Google, Mapbox, LocationIQ). Confirm ToS/rate limits; cache results; never batch against Nominatim above 1 req/sec.
6. **Write output**:
   - Small files: `json.dump({"type":"FeatureCollection","features":[...]})`.
   - Large files: stream per-feature to `.geojsonl` or chunk writes to avoid memory bloat.
   - Add a top-level `bbox` for the FeatureCollection if helpful.
7. **Validate** — optional lint via `geojson` / `geojson-pydantic`; report any invalid features.
8. **Report** — feature count, geometry-type breakdown, rows skipped/flagged, output path, CRS written (always EPSG:4326 for GeoJSON).
9. **Update the data dictionary** — record geometry source columns, CRS, geocoding provider if used.

## Dependencies

```bash
pip install pandas shapely pyproj
# optional
pip install geopandas fiona     # richer read/write of geo formats
pip install h3                  # H3 cells
pip install geopy               # geocoding
pip install geojson-pydantic    # validation
```

## Edge cases

- **Lat/lon swap** — the most common bug. Detect when "lat" values exceed ±90 or "lon" names correspond to y-axis. Ask, don't silently swap.
- **Antimeridian crossing** — polygons crossing the 180° line need splitting for most renderers. Flag and offer to split via `shapely`.
- **Very large polygons** — simplify via `shapely.simplify(tolerance)` if downstream tools choke; record the tolerance.
- **Mixed geometry types** in one collection — valid GeoJSON but some tools reject. Offer to split per-type.
- **Addresses** — refuse to geocode at scale without explicit user consent and a chosen provider; geocoding is often billable and rate-limited.

## Safety

Follow the backup policy in `CONVENTIONS.md` before any in-place rewrite. This skill by default writes a new `.geojson` or `.geojsonl` file alongside the source.
