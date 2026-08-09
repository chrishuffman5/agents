# duckdb — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 198** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| duckdb-quack-port | recent | In DuckDB, the Quack remote protocol lets one DuckDB process serve another over HTTP. What is the default port that quack_serve binds to? Answer with the exact number. | contains_all: `9494` |
| duckdb-15-codename | recent | What is the release codename for DuckDB version 1.5? Answer with just the codename. | contains_all: `Variegata` |
| duckdb-row-group-size | stable | In DuckDB's native columnar storage format, roughly how many rows does each row group contain? Answer with the exact number. | regex: `(?i)122,?880` |
| duckdb-etl-spark-threshold | stable | As a Spark replacement for small-to-medium ETL workloads, up to roughly what data volume does DuckDB comfortably handle on a single machine before a distributed cluster becomes necessary? Answer concisely. | contains_all: `200` |
| duckdb-etl-production-warehouse-size | stable | Using the dbt-duckdb adapter, DuckDB can serve as the production warehouse itself for datasets under roughly what size, with dbt managing the transformation layer? Answer concisely. | contains_all: `50` |
| duckdb-etl-copy-compression | stable | In a typical DuckDB COPY statement that converts a CSV file to Parquet format in one step, which compression codec is used in the example format conversion pattern? Answer concisely. | contains_all: `ZSTD` |
| duckdb-superset-connection | stable | When Apache Superset connects to DuckDB as a data source, what Python package provides the native SQLAlchemy dialect for it? Answer concisely. | contains_all: `duckdb-engine` |
| duckdb-warehouse-threshold | recent | Below roughly what data volume does DuckDB on a single machine tend to outperform a cloud data warehouse while costing nothing? Answer concisely. | regex: `(?i)200\s*GB` |
| duckdb-powerbi-query-modes | stable | When Power BI connects to DuckDB through the ODBC driver, what two query modes are available? Answer concisely. | contains_all: `DirectQuery``, ``Import` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `duckdb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
