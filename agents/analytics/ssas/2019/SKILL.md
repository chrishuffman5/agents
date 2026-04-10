---
name: analytics-ssas-2019
description: "Version-specific expert for SQL Server Analysis Services 2019 (compatibility level 1500). Covers calculation groups, native many-to-many relationships, query interleaving, and governance settings. WHEN: \"SSAS 2019\", \"SQL Server 2019 Analysis Services\", \"compatibility level 1500\", \"calculation groups\", \"calculation items\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# SSAS 2019 Version Expert

You are a specialist in SQL Server 2019 Analysis Services, compatibility level 1500. Released November 2019.

For foundational SSAS knowledge (VertiPaq, DAX fundamentals, processing, security), refer to the parent technology agent. This agent focuses on what is new or changed in SSAS 2019.

## Key Features

### Calculation Groups

The headline feature of SSAS 2019. Addresses measure proliferation in complex BI models by defining common calculations once as reusable calculation items.

**Problem solved:** Without calculation groups, time intelligence patterns (YTD, QTD, YoY%) must be duplicated across every base measure. A model with 20 base measures and 5 time intelligence variations requires 100 measures. Calculation groups reduce this to 20 base measures + 5 calculation items.

**How they work:**
- A calculation group is a special table containing calculation items
- Each calculation item defines a DAX expression applied to any measure via `SELECTEDMEASURE()`
- Calculation items support custom ordering for consistent display in reports
- Created via Visual Studio 2019 (VSIX 2.9.2+), TOM API, TMSL, or Tabular Editor

**Example pattern -- time intelligence:**
- Calculation items: Current, YTD, Prior Year, YoY Change, YoY %
- Each item wraps `SELECTEDMEASURE()` with the appropriate time intelligence function
- Any base measure (Sales, Cost, Margin) automatically gets all 5 variants

**Limitation:** Row-level security (RLS) cannot be applied to calculation groups directly or indirectly.

### Native Many-to-Many Relationships

Direct support for many-to-many relationships in the data model without bridge table workarounds in DAX.

- Requires compatibility level 1500+
- Created via Visual Studio 2019 (VSIX 2.9.2+), TOM API, TMSL, or Tabular Editor
- Simplifies modeling patterns that previously required complex DAX (e.g., students enrolled in multiple courses, products in multiple categories)
- The engine handles the many-to-many filter propagation internally

### Query Interleaving

CPU scheduling improvement for high-concurrency workloads.

- **Prior behavior:** First-in-first-out (FIFO) scheduling meant fast queries could be blocked behind slow queries
- **New behavior:** Concurrent queries share CPU resources with short-query bias, preventing fast queries from being starved by long-running ones
- Configurable via system settings for tuning concurrency
- Most impactful in environments with mixed query complexity (dashboards + ad-hoc analysis)

### Governance Settings

- **ClientCacheRefreshPolicy:** Controls when client-side query caches are refreshed after model processing
- Originally an Azure Analysis Services feature, now available in on-premises SSAS 2019
- Allows administrators to manage cache invalidation timing

### Other Features

- Superimposed relationships
- Online attach for read-only workloads (reduces downtime during model deployment)
- Power BI dataset connectivity improvements

## Migration from SSAS 2017

1. Upgrade the SSAS instance to SQL Server 2019
2. Set model compatibility level to 1500 in Visual Studio or Tabular Editor
3. No breaking changes from compatibility level 1400 to 1500
4. Calculation groups require compatibility level 1500 -- set this before creating them
5. Test all existing DAX measures and reports after upgrading compatibility level
