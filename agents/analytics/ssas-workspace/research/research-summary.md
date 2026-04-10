# SSAS Research Summary

## Key Findings

### Platform Direction
- Microsoft's strategic investment is focused on the Tabular engine and Power BI/Fabric. Multidimensional mode is in maintenance mode with no major new features planned
- Azure Analysis Services is being positioned for migration to Power BI/Fabric. Microsoft actively recommends this migration path
- Power BI Premium per-capacity SKUs are being retired in favor of Fabric capacity (F SKUs)
- SSAS on-premises remains supported through SQL Server 2025 with meaningful performance improvements, but cloud-first is the clear strategic direction

### SSAS 2025 is a Meaningful Release
- Not just a maintenance release: includes Horizontal Fusion for DirectQuery, enhanced parallelism, selection expressions for calculation groups, new DAX functions (LINEST/LINESTX), binary XML communication, and improved diagnostics via XEvents
- Shows continued on-prem investment, particularly for organizations that cannot or choose not to move to cloud

### Tabular vs. Multidimensional Decision is Clear
- New projects should use Tabular mode unless there is a specific, documented requirement for Multidimensional features (writeback, actions, linked measure groups)
- Migration from Multidimensional to Tabular requires a complete redesign (60-80% of original dev time) -- it is not a simple conversion

### VertiPaq Compression is the Critical Performance Factor
- Column cardinality is the #1 driver of model size and memory consumption
- Optimizing cardinality (splitting columns, removing unnecessary columns, choosing correct data types) can reduce model size by 90%+
- DAX Studio and VertiPaq Analyzer are essential diagnostic tools

### DAX Performance Has Well-Established Patterns
- Variables, avoiding nested iterators, and understanding Storage Engine vs. Formula Engine bottlenecks are the core optimization techniques
- SUMMARIZECOLUMNS is the most optimized aggregation function
- Formula Engine bottlenecks (single-threaded, cache-resistant) are harder to fix than Storage Engine bottlenecks

---

## Confidence Levels

| Topic | Confidence | Notes |
|-------|------------|-------|
| Architecture (Tabular/Multidimensional) | High | Well-documented by Microsoft and the community; stable for many years |
| VertiPaq engine internals | High | Extensive documentation from SQLBI (Marco Russo, Alberto Ferrari) |
| DAX best practices | High | Mature, well-tested patterns from SQLBI, community, and Microsoft |
| SSAS 2019 features | High | GA for 6+ years; well documented |
| SSAS 2022 features | High | GA for 3+ years; well documented |
| SSAS 2025 features | Medium-High | Based on Microsoft Learn docs and official blog posts; SQL Server 2025 is released but community experience is still accumulating |
| Migration guidance | High | Extensively covered by consultancies and Microsoft documentation |
| Platform convergence (Fabric) | Medium-High | Strategic direction is clear but timelines for AAS retirement and feature parity details evolve |
| Diagnostics tools | High | DAX Studio, VertiPaq Analyzer, XEvents are mature, well-documented tools |
| Security patterns | High | Dynamic RLS, OLS are well-established patterns with extensive community documentation |
| Processing optimization | High | Partition strategies and processing types are stable and well-documented |
| Deployment/CI/CD | Medium-High | Tabular Editor and TMSL are well documented; CI/CD patterns exist but require custom scripting compared to modern platforms |

---

## Research Gaps

1. **SSAS 2025 real-world performance benchmarks**: The release is recent enough that independent benchmarks comparing 2022 vs. 2025 performance improvements are limited. Microsoft's blog posts describe improvements but quantified comparisons from the community are sparse

2. **Fabric semantic model feature parity with SSAS**: The exact feature gap between SSAS on-prem and Power BI/Fabric semantic models continues to evolve. Some SSAS features (e.g., perspectives, translations) have varying levels of Fabric support

3. **SSAS Multidimensional deprecation timeline**: Microsoft has not announced a formal end-of-life or deprecation date for Multidimensional mode. It is supported in SQL Server 2025 but with no new features

4. **Large-scale dynamic RLS performance**: While patterns are well-documented, performance characteristics of dynamic RLS with tens of thousands of users and complex security hierarchies are less documented outside of specific case studies

5. **Tabular Editor 3 vs. SSDT for enterprise teams**: The tooling landscape is evolving. Tabular Editor 3 is increasingly preferred but enterprise adoption patterns and licensing considerations are community-dependent

---

## Sources

### Microsoft Official
- [What's new in SQL Server 2025 Analysis Services](https://learn.microsoft.com/en-us/analysis-services/what-s-new-in-sql-server-analysis-services?view=sql-analysis-services-2025)
- [What's New in SQL Server 2025 Analysis Services (Power BI Blog)](https://powerbi.microsoft.com/en-us/blog/whats-new-in-sql-server-2025-analysis-services/)
- [Enhancing reporting and analytics with SQL Server 2025](https://www.microsoft.com/en-us/sql-server/blog/2025/06/19/enhancing-reporting-and-analytics-with-sql-server-2025-tools-and-services/)
- [Comparing tabular and multidimensional models](https://learn.microsoft.com/en-us/analysis-services/comparing-tabular-and-multidimensional-solutions-ssas?view=sql-analysis-services-2025)
- [SSAS Overview](https://learn.microsoft.com/en-us/analysis-services/ssas-overview?view=sql-analysis-services-2025)
- [Analysis Services client libraries](https://learn.microsoft.com/en-us/analysis-services/client-libraries?view=asallproducts-allversions)
- [TMSL Reference](https://learn.microsoft.com/en-us/analysis-services/tmsl/tabular-model-scripting-language-tmsl-reference?view=asallproducts-allversions)
- [Partition storage modes and processing](https://learn.microsoft.com/en-us/analysis-services/multidimensional-models-olap-logical-cube-objects/partitions-partition-storage-modes-and-processing?view=asallproducts-allversions)
- [Object-level security](https://learn.microsoft.com/en-us/analysis-services/tabular-models/object-level-security?view=asallproducts-allversions)
- [Migrate Azure Analysis Services to Power BI](https://learn.microsoft.com/en-us/fabric/enterprise/powerbi/aas-pbi-migration-overview)
- [Aggregations and aggregation designs](https://learn.microsoft.com/en-us/analysis-services/multidimensional-models-olap-logical-cube-objects/aggregations-and-aggregation-designs?view=asallproducts-allversions)
- [Perspectives in tabular models](https://learn.microsoft.com/en-us/analysis-services/tabular-models/perspectives-ssas-tabular?view=asallproducts-allversions)
- [CALCULATE function (DAX)](https://learn.microsoft.com/en-us/dax/calculate-function-dax)
- [SSAS 2019 RC1 features](https://powerbi.microsoft.com/en-us/blog/whats-new-for-sql-server-2019-analysis-services-rc1/)
- [XMLA endpoint in Power BI](https://learn.microsoft.com/en-us/fabric/enterprise/powerbi/service-premium-connect-tools)

### SQLBI (Marco Russo / Alberto Ferrari)
- [Optimizing high cardinality columns in VertiPaq](https://www.sqlbi.com/articles/optimizing-high-cardinality-columns-in-vertipaq/)
- [Data model size with VertiPaq Analyzer](https://www.sqlbi.com/articles/data-model-size-with-vertipaq-analyzer/)
- [Optimizing nested iterators in DAX](https://www.sqlbi.com/articles/optimizing-nested-iterators-in-dax/)
- [SUMMARIZECOLUMNS best practices](https://www.sqlbi.com/articles/summarizecolumns-best-practices/)
- [Formula engine and storage engine in DAX](https://www.sqlbi.com/articles/formula-engine-and-storage-engine-in-dax/)
- [Row context and filter context in DAX](https://www.sqlbi.com/articles/row-context-and-filter-context-in-dax/)
- [VertiPaq Analyzer](https://www.sqlbi.com/tools/vertipaq-analyzer/)
- [ALM Toolkit](https://www.sqlbi.com/tools/alm-toolkit/)

### Community / Third-Party
- [SSAS Today - SQLyard](https://sqlyard.com/2025/11/15/ssas-today-new-features-why-it-still-gets-used-and-when-it-makes-sense-in-modern-data-platforms/)
- [Inside VertiPaq: Compress for Success - Data Mozart](https://data-mozart.com/inside-vertipaq-compress-for-success/)
- [Improve DAX Performance - The Data Community](https://thedatacommunity.org/2025/12/28/improve-dax-performance/)
- [DAX Studio documentation](https://daxstudio.org/docs/features/model-metrics/)
- [Tabular Editor CI/CD scripts](https://tabulareditor.com/blog/ci-cd-scripts-for-tabular-editor-2s-cli)
- [Tabular Editor deployment docs](https://docs.tabulareditor.com/te3/features/deployment.html)
- [Dynamic security with SSAS and Power BI](https://www.kasperonbi.com/dynamic-security-made-easy-with-ssas-2016-and-power-bi/)
- [SSAS performance tuning best practices - Mindmajix](https://mindmajix.com/msbi/best-practices-for-performance-tuning-in-ssas-cube)
