# DuckDB Universal File Reading Reference

The `read_any` table macro pattern for auto-detecting and reading arbitrary file formats.

---

## Universal File Reading with read_any Macro

DuckDB can auto-detect and read virtually any data format using a `read_any` table macro pattern. This is useful when the file format is unknown or when building tools that handle arbitrary data files:

```sql
-- The read_any macro dispatches to the correct reader based on file extension
CREATE OR REPLACE MACRO read_any(file_name) AS TABLE
  WITH json_case AS (FROM read_json_auto(file_name))
     , csv_case AS (FROM read_csv(file_name))
     , parquet_case AS (FROM read_parquet(file_name))
     , avro_case AS (FROM read_avro(file_name))
     , blob_case AS (FROM read_blob(file_name))
     , spatial_case AS (FROM st_read(file_name))
     , excel_case AS (FROM read_xlsx(file_name))
     , sqlite_case AS (FROM sqlite_scan(file_name,
         (SELECT name FROM sqlite_master(file_name) LIMIT 1)))
  FROM query_table(
    CASE
      WHEN file_name ILIKE '%.json' OR file_name ILIKE '%.jsonl'
        OR file_name ILIKE '%.ndjson' OR file_name ILIKE '%.geojson' THEN 'json_case'
      WHEN file_name ILIKE '%.csv' OR file_name ILIKE '%.tsv'
        OR file_name ILIKE '%.tab' OR file_name ILIKE '%.txt' THEN 'csv_case'
      WHEN file_name ILIKE '%.parquet' OR file_name ILIKE '%.pq' THEN 'parquet_case'
      WHEN file_name ILIKE '%.avro' THEN 'avro_case'
      WHEN file_name ILIKE '%.xlsx' OR file_name ILIKE '%.xls' THEN 'excel_case'
      WHEN file_name ILIKE '%.shp' OR file_name ILIKE '%.gpkg'
        OR file_name ILIKE '%.fgb' OR file_name ILIKE '%.kml' THEN 'spatial_case'
      WHEN file_name ILIKE '%.db' OR file_name ILIKE '%.sqlite'
        OR file_name ILIKE '%.sqlite3' THEN 'sqlite_case'
      ELSE 'blob_case'
    END
  );

-- Usage
FROM read_any('data.csv') LIMIT 10;
DESCRIBE FROM read_any('mystery_file.parquet');
```

**Supported formats via read_any:**
| Extension | Reader | Extension Required |
|---|---|---|
| `.json`, `.jsonl`, `.ndjson`, `.geojson` | `read_json_auto` | json (auto-loaded) |
| `.csv`, `.tsv`, `.tab`, `.txt` | `read_csv` | (built-in) |
| `.parquet`, `.pq` | `read_parquet` | parquet (auto-loaded) |
| `.avro` | `read_avro` | (built-in) |
| `.xlsx`, `.xls` | `read_xlsx` | excel |
| `.shp`, `.gpkg`, `.fgb`, `.kml` | `st_read` | spatial |
| `.db`, `.sqlite`, `.sqlite3` | `sqlite_scan` | sqlite_scanner |
