/*******************************************************************************
 * SQL Server 2022 (Compatibility Level 160) - Ledger Health & Monitoring
 *
 * Purpose : NEW for 2022. Monitor ledger tables, transactions, block chain
 *           integrity, and digest storage.
 * Version : 2022.1.0
 * Targets : SQL Server 2022+ (build 16.x)
 * Safety  : Read-only. No modifications to data or configuration.
 *           (Section 7 calls sp_verify_database_ledger which is read-only.)
 *
 * Sections:
 *   1. Ledger Database Status
 *   2. Ledger-Enabled Tables & Types (Append-Only vs Updatable)
 *   3. Ledger Table Column Mappings
 *   4. Transaction History (sys.database_ledger_transactions)
 *   5. Block Chain Status (sys.database_ledger_blocks)
 *   6. Digest Storage Configuration
 *   7. Database Ledger Verification (sp_verify_database_ledger)
 *   8. Ledger View Analysis
 ******************************************************************************/
SET NOCOUNT ON;

/*──────────────────────────────────────────────────────────────────────────────
  Section 1: Ledger Database Status — NEW in 2022
──────────────────────────────────────────────────────────────────────────────*/
SELECT
    d.database_id,
    d.name                                          AS database_name,
    d.is_ledger_on                                  AS ledger_database,          -- NEW in 2022
    d.state_desc                                    AS database_state,
    d.compatibility_level,
    CASE d.is_ledger_on
        WHEN 1 THEN 'Ledger database — all tables are ledger tables by default'
        WHEN 0 THEN 'Standard database — ledger tables can be created explicitly'
        ELSE 'Unknown'
    END                                             AS ledger_description
FROM sys.databases AS d
WHERE d.state = 0  -- ONLINE
ORDER BY d.is_ledger_on DESC, d.name;

/*──────────────────────────────────────────────────────────────────────────────
  Section 2: Ledger-Enabled Tables & Types — NEW in 2022
  Lists all ledger tables: append-only vs updatable.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_columns WHERE object_id = OBJECT_ID('sys.tables') AND name = 'ledger_type')
BEGIN
    SELECT
        OBJECT_SCHEMA_NAME(t.object_id)             AS schema_name,
        t.name                                      AS table_name,
        t.ledger_type,                                                          -- NEW in 2022
        t.ledger_type_desc,                                                     -- NEW in 2022
        CASE t.ledger_type
            WHEN 1 THEN 'Updatable ledger table — supports UPDATE/DELETE with history'
            WHEN 2 THEN 'Append-only ledger table — INSERT only'
            ELSE 'Not a ledger table'
        END                                         AS ledger_description,
        t.ledger_view_id,                                                       -- NEW in 2022
        OBJECT_NAME(t.ledger_view_id)               AS ledger_view_name,        -- NEW in 2022
        t.create_date,
        t.modify_date,
        ps.row_count                                AS approximate_rows,
        ps.reserved_page_count * 8 / 1024           AS table_size_mb
    FROM sys.tables AS t
    LEFT JOIN sys.dm_db_partition_stats AS ps
        ON t.object_id = ps.object_id
       AND ps.index_id IN (0, 1)  -- heap or clustered
    WHERE t.ledger_type IS NOT NULL
      AND t.ledger_type > 0
    ORDER BY t.ledger_type_desc, schema_name, table_name;

    -- Summary by ledger type
    SELECT
        t.ledger_type_desc                          AS ledger_type,
        COUNT(*)                                    AS table_count,
        SUM(ps.row_count)                           AS total_rows,
        SUM(ps.reserved_page_count) * 8 / 1024     AS total_size_mb
    FROM sys.tables AS t
    LEFT JOIN sys.dm_db_partition_stats AS ps
        ON t.object_id = ps.object_id
       AND ps.index_id IN (0, 1)
    WHERE t.ledger_type IS NOT NULL
      AND t.ledger_type > 0
    GROUP BY t.ledger_type_desc;
END
ELSE
BEGIN
    SELECT 'Ledger table columns not available. Requires SQL Server 2022+.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 3: Ledger Table Column Mappings — NEW in 2022
  Shows the system-generated columns for ledger tracking.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'ledger_table_history' AND type = 'V')
BEGIN
    SELECT
        OBJECT_SCHEMA_NAME(lc.object_id)            AS schema_name,
        OBJECT_NAME(lc.object_id)                   AS table_name,
        c.name                                      AS column_name,
        lc.column_type_desc                         AS ledger_column_type,      -- NEW in 2022
        TYPE_NAME(c.user_type_id)                   AS data_type,
        c.is_hidden                                 AS is_hidden_column
    FROM sys.ledger_column_history AS lc                                        -- NEW in 2022
    INNER JOIN sys.columns AS c
        ON lc.object_id = c.object_id
       AND lc.column_id = c.column_id
    ORDER BY schema_name, table_name, lc.column_type_desc;
END
ELSE
BEGIN
    -- Alternative: check for ledger-related hidden columns
    SELECT
        OBJECT_SCHEMA_NAME(c.object_id)             AS schema_name,
        OBJECT_NAME(c.object_id)                    AS table_name,
        c.name                                      AS column_name,
        TYPE_NAME(c.user_type_id)                   AS data_type,
        c.generated_always_type_desc                AS generated_type,
        c.is_hidden
    FROM sys.columns AS c
    INNER JOIN sys.tables AS t
        ON c.object_id = t.object_id
    WHERE c.is_hidden = 1
      AND t.ledger_type IS NOT NULL
      AND t.ledger_type > 0
    ORDER BY schema_name, table_name, c.column_id;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 4: Transaction History — NEW in 2022
  sys.database_ledger_transactions contains committed transactions
  that modified ledger tables.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'database_ledger_transactions' AND type = 'V')
BEGIN
    -- Recent ledger transactions (last 24 hours, top 100)
    SELECT TOP (100)
        transaction_id,
        block_id,
        transact_id,
        commit_time,
        principal_name                              AS committed_by,
        table_hashes                                AS table_hashes_json
    FROM sys.database_ledger_transactions                                       -- NEW in 2022
    WHERE commit_time > DATEADD(HOUR, -24, GETUTCDATE())
    ORDER BY commit_time DESC;

    -- Transaction volume by hour
    SELECT
        DATEADD(HOUR, DATEDIFF(HOUR, 0, commit_time), 0) AS hour_bucket,
        COUNT(*)                                    AS transaction_count,
        COUNT(DISTINCT principal_name)              AS distinct_users
    FROM sys.database_ledger_transactions                                       -- NEW in 2022
    WHERE commit_time > DATEADD(DAY, -7, GETUTCDATE())
    GROUP BY DATEADD(HOUR, DATEDIFF(HOUR, 0, commit_time), 0)
    ORDER BY hour_bucket DESC;
END
ELSE
BEGIN
    SELECT 'sys.database_ledger_transactions not available. Requires SQL Server 2022+ with ledger enabled.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 5: Block Chain Status — NEW in 2022
  sys.database_ledger_blocks contains the blockchain blocks that
  protect the integrity of ledger data.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'database_ledger_blocks' AND type = 'V')
BEGIN
    -- Latest blocks
    SELECT TOP (50)
        block_id,
        block_size,
        transactions_root_hash,
        previous_block_hash,
        block_hash,
        CASE
            WHEN previous_block_hash IS NOT NULL THEN 'Chained'
            WHEN block_id = 0                    THEN 'Genesis block'
            ELSE 'Unchained (investigate)'
        END                                         AS chain_status
    FROM sys.database_ledger_blocks                                             -- NEW in 2022
    ORDER BY block_id DESC;

    -- Block chain summary
    SELECT
        COUNT(*)                                    AS total_blocks,
        MIN(block_id)                               AS first_block_id,
        MAX(block_id)                               AS last_block_id,
        SUM(block_size)                             AS total_transactions_in_blocks,
        CASE
            WHEN COUNT(*) > 0
             AND MAX(block_id) - MIN(block_id) + 1 = COUNT(*)
            THEN 'Contiguous (healthy)'
            ELSE 'Gaps detected (investigate!)'
        END                                         AS chain_continuity
    FROM sys.database_ledger_blocks;
END
ELSE
BEGIN
    SELECT 'sys.database_ledger_blocks not available. Requires SQL Server 2022+ with ledger enabled.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 6: Digest Storage Configuration — NEW in 2022
  Shows where ledger digests are stored for tamper-evidence verification.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'database_ledger_digest_locations' AND type = 'V')
BEGIN
    SELECT
        path                                        AS digest_storage_path,
        last_digest_block_id,
        is_current                                  AS is_active_location
    FROM sys.database_ledger_digest_locations                                   -- NEW in 2022
    ORDER BY is_current DESC, last_digest_block_id DESC;
END
ELSE
BEGIN
    SELECT 'Ledger digest location catalog view not available.' AS info_message;
END;

/*──────────────────────────────────────────────────────────────────────────────
  Section 7: Database Ledger Verification — NEW in 2022
  Runs sp_verify_database_ledger to verify block chain integrity.
  This is a read-only operation.
──────────────────────────────────────────────────────────────────────────────*/
-- Note: sp_verify_database_ledger requires a digest as input.
-- The following generates the latest digest and could verify against it.
-- Uncomment and adjust if you have digest storage configured.

/*
-- Generate the latest digest
DECLARE @digest NVARCHAR(MAX);
EXEC sp_generate_database_ledger_digest @digest OUTPUT;
SELECT @digest AS latest_digest;

-- Verify the ledger (read-only check)
-- EXEC sp_verify_database_ledger @digest;
*/

-- Instead, show verification readiness
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM sys.tables WHERE ledger_type IS NOT NULL AND ledger_type > 0)
        THEN 'Ledger tables exist — verification can be performed'
        ELSE 'No ledger tables found — verification not applicable'
    END                                             AS verification_readiness,
    (SELECT COUNT(*) FROM sys.tables WHERE ledger_type > 0)
                                                    AS ledger_table_count,
    CASE
        WHEN EXISTS (SELECT 1 FROM sys.all_objects WHERE name = 'database_ledger_blocks')
        THEN (SELECT COUNT(*) FROM sys.database_ledger_blocks)
        ELSE 0
    END                                             AS block_count;

/*──────────────────────────────────────────────────────────────────────────────
  Section 8: Ledger View Analysis — NEW in 2022
  Ledger views provide the full history of changes for updatable ledger tables.
──────────────────────────────────────────────────────────────────────────────*/
IF EXISTS (SELECT 1 FROM sys.all_columns WHERE object_id = OBJECT_ID('sys.tables') AND name = 'ledger_view_id')
BEGIN
    SELECT
        OBJECT_SCHEMA_NAME(t.object_id)             AS table_schema,
        t.name                                      AS table_name,
        t.ledger_type_desc                          AS table_ledger_type,
        OBJECT_SCHEMA_NAME(t.ledger_view_id)        AS view_schema,
        OBJECT_NAME(t.ledger_view_id)               AS ledger_view_name,
        v.type_desc                                 AS view_type,
        CASE
            WHEN t.ledger_view_id IS NOT NULL
            THEN 'SELECT * FROM '
                 + QUOTENAME(OBJECT_SCHEMA_NAME(t.ledger_view_id))
                 + '.' + QUOTENAME(OBJECT_NAME(t.ledger_view_id))
                 + ' -- to see full change history'
            ELSE 'No ledger view (append-only tables do not have views)'
        END                                         AS query_hint
    FROM sys.tables AS t
    LEFT JOIN sys.views AS v
        ON t.ledger_view_id = v.object_id
    WHERE t.ledger_type IS NOT NULL
      AND t.ledger_type > 0
    ORDER BY table_schema, table_name;
END
ELSE
BEGIN
    SELECT 'Ledger view analysis requires SQL Server 2022+.' AS info_message;
END;
