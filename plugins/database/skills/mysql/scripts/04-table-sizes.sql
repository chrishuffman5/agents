-- Purpose:        Largest tables with index share and free-space fragmentation - capacity and rebuild-candidate map
-- Applies to:     MySQL 8.0+ (InnoDB)
-- Read-only:      yes
-- Inputs:         optionally filter AND table_schema = '__SCHEMA__'
-- Interpretation: index_mb rivaling or exceeding data_mb = index sprawl - cross-check usage in sys.schema_unused_indexes
--                 before dropping. data_free_mb large relative to the table (after big deletes) = reclaimable space via
--                 OPTIMIZE TABLE / ALTER ... FORCE, but that is an online-DDL rebuild - schedule it. Sizes are
--                 statistics-based; run ANALYZE TABLE first when precision matters.
-- Next step:      sys.schema_unused_indexes for the drop list; plan rebuilds for the fragmented giants

SELECT
    table_schema,
    table_name,
    table_rows,
    ROUND(data_length  / 1048576, 1) AS data_mb,
    ROUND(index_length / 1048576, 1) AS index_mb,
    ROUND(data_free    / 1048576, 1) AS data_free_mb,
    engine
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql', 'sys', 'information_schema', 'performance_schema')
ORDER BY data_length + index_length DESC
LIMIT 30
