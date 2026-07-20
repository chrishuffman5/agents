-- Purpose:        Size every table and partition in the current Tabular model (rows and bytes) to find bloat and skew
-- Applies to:     SSAS Tabular 2016+ (compatibility 1200+); also Azure AS and Power BI via XMLA
-- Read-only:      yes
-- Inputs:         connect with the target model set as the current database (SSMS: pick it in the database dropdown)
-- How to run:     SSMS MDX query window or DAX Studio against the target database
-- Interpretation: DIMENSION_NAME = table. Tables whose USED_SIZE is far above their analytical value are candidates for
--                 column pruning or filtering at import. RIVIOLATION_COUNT > 0 indicates referential integrity violations
--                 (blank row hits) worth fixing in the source.
-- Next step:      03-object-memory.sql for instance-wide view; VertiPaq Analyzer for per-column compression detail

SELECT
    DIMENSION_NAME,
    TABLE_ID,
    TABLE_PARTITIONS_COUNT,
    ROWS_COUNT,
    USED_SIZE,
    RIVIOLATION_COUNT
FROM $SYSTEM.DISCOVER_STORAGE_TABLES
ORDER BY USED_SIZE DESC
