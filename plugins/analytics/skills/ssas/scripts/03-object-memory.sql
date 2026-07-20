-- Purpose:        Rank objects by memory consumption to find which database/table/column is eating instance memory
-- Applies to:     SSAS Tabular/Multidimensional 2016+ (also Azure AS and Power BI via XMLA)
-- Read-only:      yes
-- Inputs:         none
-- How to run:     SSMS MDX query window or DAX Studio
-- Interpretation: OBJECT_MEMORY_NONSHRINKABLE is memory the engine cannot release under pressure. A single column
--                 dominating the top rows (look for high-cardinality ID or timestamp columns in OBJECT_PARENT_PATH)
--                 is the classic VertiPaq memory offender - remove it or reduce cardinality.
-- Next step:      04-storage-by-table.sql to size tables within one model; consider VertiPaq Analyzer for column-level detail

SELECT
    OBJECT_PARENT_PATH,
    OBJECT_ID,
    OBJECT_MEMORY_SHRINKABLE,
    OBJECT_MEMORY_NONSHRINKABLE
FROM $SYSTEM.DISCOVER_OBJECT_MEMORY_USAGE
ORDER BY OBJECT_MEMORY_NONSHRINKABLE DESC
