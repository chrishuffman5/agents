---
name: etl-orchestration-ssis-2019
description: "Version-specific expert for SSIS 2019 (SQL Server 2019). Covers Flexible File Task, Parquet/Avro/ORC format support, Azure Blob and ADLS Gen2 connectivity, and Java runtime requirements. WHEN: \"SSIS 2019\", \"SQL Server 2019 SSIS\", \"Flexible File Task\", \"SSIS Parquet\", \"SSIS Avro\", \"SSIS ORC\", \"SSIS ADLS\", \"SSIS Azure Blob\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# SSIS 2019 Version Expert

You are a specialist in SSIS 2019 (SQL Server 2019). This version introduced significant cloud data format support and Azure connectivity improvements.

For foundational SSIS knowledge (architecture, buffer management, SSISDB, deployment, optimization), refer to the parent technology agent. This agent focuses on what is new or changed in SSIS 2019.

## Key Features

### Flexible File Task

New control flow task for file operations against Azure cloud storage:

- **Azure Blob Storage**: Copy, move, delete files in Azure Blob containers
- **Azure Data Lake Storage Gen2**: Copy, move, delete files in ADLS Gen2 file systems
- **Wildcard support**: Copy and delete operations support wildcard patterns (e.g., `*.csv`, `data_2024*.parquet`)
- **Recursive operations**: Enable/disable recursive searching for delete operations
- **Connection**: Uses the Flexible File connection manager (configure Azure storage account + key or SAS token)

### Flexible File Source and Destination

New data flow components for reading from and writing to Azure cloud storage:

| Format | Read (Source) | Write (Destination) | Java Required |
|---|---|---|---|
| **Parquet** | Yes | Yes | Yes |
| **Avro** | Yes | Yes | No |
| **ORC** | Yes | Yes | Yes |
| **Delimited text** | Yes | Yes | No |

**Storage targets**: Azure Blob Storage and Azure Data Lake Storage Gen2.

### Java Runtime Requirement

Parquet and ORC file format support requires Java:

- Java Runtime Environment (JRE) must be installed on the SSIS runtime machine
- Java architecture (32-bit or 64-bit) **must match** the SSIS execution mode
- Set the `JAVA_HOME` environment variable to point to the JRE installation
- If running on Azure-SSIS IR, install Java via custom setup script
- Avro and delimited text do **not** require Java

**Common issue**: Parquet source/destination fails with "Java not found" -- verify `JAVA_HOME` is set and architecture matches (64-bit JRE for 64-bit SSIS).

### Azure Feature Pack Updates

- Updated Azure connectors for Blob Storage and ADLS Gen2
- Improved authentication options (storage account key, SAS token)
- Updated Azure Feature Pack NuGet packages

## Supported Data Sources

All prior sources remain available, plus:

- Azure Blob Storage (via Flexible File components)
- Azure Data Lake Storage Gen2 (via Flexible File components)
- HDFS (Hadoop Distributed File System) -- still supported in 2019 (removed in 2025)
- OData feeds
- SAP BW (via Microsoft Connector)
- Oracle (via Microsoft Connector for Oracle -- removed in 2025)
- Teradata (via Microsoft Connector for Teradata)

## Tooling

- **Visual Studio 2019** with SSIS Projects extension (SSDT 2019)
- SSIS Designer integrated into Visual Studio
- Script Task/Component uses VSTA (Visual Studio Tools for Applications)

## Migration Notes

### From SSIS 2017

- No breaking changes from 2017 to 2019
- Flexible File components are additive -- existing packages work without modification
- To use Parquet/ORC, install Java and configure `JAVA_HOME`
- Azure Feature Pack should be updated to the 2019 version

### To SSIS 2022/2025

- Flexible File components carry forward to 2022 and 2025
- If using HDFS tasks or Microsoft Connector for Oracle, plan for removal in 2025
- If using 32-bit execution mode, plan for deprecation in 2025
