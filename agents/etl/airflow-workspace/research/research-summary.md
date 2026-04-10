# Apache Airflow Research Summary

## Research Date
April 2026

## Current State
- **Latest stable release:** Airflow 3.2.0 (April 2026)
- **Latest patch release:** Airflow 3.0.6 / 3.1.8 (patch lines maintained)
- **Airflow 2.x:** End of Life April 2026; last feature release was 2.10 (September 2024); final patch 2.11.2
- **Adoption:** 80,000+ organizations; monthly downloads increased 30x since 2020

## Key Findings

### 1. Airflow 3 is a Fundamental Architecture Shift

**Confidence: HIGH** (based on official documentation, release blog, migration guides)

Airflow 3.0 (April 2025) is the most significant release in Airflow's history, introducing a client-server architecture where tasks communicate via the API Server instead of direct database access. This is not an incremental upgrade -- it changes how tasks execute, how DAGs are deployed, and how security works. The Task Execution Interface (AIP-72) enables remote execution across environments and sets the foundation for multi-language Task SDKs.

### 2. Migration from 2.x to 3.x Requires Significant Effort

**Confidence: HIGH** (based on official migration guide, Astronomer checklist, AWS migration blog)

The migration is not in-place; a new environment is recommended. Key efforts include:
- Replacing deprecated import paths (automated via Ruff linter)
- Removing direct database access from custom operators/DAGs (biggest effort)
- Replacing SubDAGs with TaskGroups
- Updating context variable references (execution_date -> logical_date)
- Reconfiguring authentication (FAB moved to provider package)
- Installing `apache-airflow-providers-standard` for previously-core operators

The Ruff linter with AIR rules (AIR301, AIR302, AIR311, AIR312) provides automated detection and partial auto-fix of breaking changes.

### 3. Airflow 3.x Feature Velocity is High

**Confidence: HIGH** (based on release notes for 3.0, 3.1, 3.2)

Each minor release adds substantial features:
- 3.0: Architecture overhaul, DAG versioning, new UI, Assets, Edge Executor
- 3.1: Human-in-the-Loop workflows, Deadline Alerts, i18n, React plugin system
- 3.2: Asset partitioning, multi-team deployments, sync deadline callbacks

This pace suggests Airflow 3.x is maturing rapidly and will continue adding enterprise features.

### 4. DAG Bundles Replace Git-Sync

**Confidence: HIGH** (based on official documentation)

Airflow 3 introduces DAG bundles as the native mechanism for DAG file sourcing, with built-in Git and S3 integration. This replaces the git-sync sidecar pattern commonly used in Kubernetes deployments. Git bundles support versioning; S3 bundles do not. Some early issues reported (e.g., S3 bundle sync problems, Git connection issues), suggesting the feature is still stabilizing.

### 5. Asset Partitioning is a Game-Changer for ETL

**Confidence: MEDIUM-HIGH** (based on 3.2 release blog and documentation; feature is brand new)

Asset partitioning (Airflow 3.2) enables triggering downstream DAGs based on specific data partitions rather than the entire asset. This is highly relevant for ETL teams dealing with partitioned data (date partitions, region partitions, etc.) and should significantly reduce unnecessary reprocessing.

### 6. KubernetesExecutor is the Future Direction

**Confidence: HIGH** (based on architecture trends, edge executor, task isolation focus)

The architecture changes in Airflow 3 (task isolation, API-based communication, per-task resource control) align strongly with container-based execution. The KubernetesExecutor and Edge Executor are the natural fits for the new architecture. CeleryExecutor remains supported but the hybrid executors (CeleryKubernetesExecutor, LocalKubernetesExecutor) were removed in favor of the more flexible Multiple Executors Concurrently feature.

### 7. Metadata Database Maintenance is Critical

**Confidence: HIGH** (based on official best practices, community discussions, managed service documentation)

Airflow never automatically cleans metadata. Production deployments must implement regular cleanup (via `airflow db clean` CLI or maintenance DAGs) to prevent scheduler performance degradation. Tables exceeding ~50 GB cause noticeable slowdowns. This is a universal issue across self-managed and some managed deployments.

### 8. Security Model is Significantly Stronger in 3.x

**Confidence: HIGH** (based on architecture documentation, migration guide)

Airflow 3 fundamentally improves security by eliminating direct database access from worker tasks. DAG authors can no longer run arbitrary database queries. Combined with the API-based task execution and the separation of Flask AppBuilder into a provider package, the attack surface is substantially reduced. Multi-team isolation (3.2) adds another layer of security for enterprise deployments.

## Gaps and Uncertainties

### Items Needing Further Research

1. **Task SDK multi-language support:** Golang SDK is planned but no release timeline found. The extent of non-Python language support remains unclear.

2. **Asset partitioning real-world patterns:** Airflow 3.2 is very new (April 2026). Real-world adoption patterns, edge cases, and limitations are not yet well-documented in community blogs or case studies.

3. **Multi-team deployment operational experience:** Also brand new in 3.2. How it works in practice at scale, integration with RBAC/SSO, and operational gotchas are not yet documented.

4. **Performance benchmarks:** No quantitative comparisons found between Airflow 2.x and 3.x scheduler performance, DAG parsing speed, or task startup latency.

5. **Managed service Airflow 3 support:** MWAA has announced Airflow 3 support (Airflow Summit 2026 session). Cloud Composer and Astronomer support status should be verified for specific 3.x versions.

6. **Multiple Executors stability:** Known bugs exist in Airflow 3.0.6 with task routing when using multiple executors concurrently. The feature may not be fully stable yet for production use.

7. **DAG bundle stability:** Reports of issues with S3 and Git DAG bundles suggest the feature is still maturing. Teams should test thoroughly before relying on it in production.

## Sources Used

### Official Documentation
- [Apache Airflow Documentation (3.2.0)](https://airflow.apache.org/docs/apache-airflow/stable/)
- [Airflow 3.0 Release Blog](https://airflow.apache.org/blog/airflow-three-point-oh-is-here/)
- [Airflow 3.2.0 Release Blog](https://airflow.apache.org/blog/airflow-3.2.0/)
- [Upgrading to Airflow 3](https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html)
- [Airflow Task SDK](https://airflow.apache.org/docs/task-sdk/stable/index.html)
- [Airflow Helm Chart](https://airflow.apache.org/docs/helm-chart/stable/index.html)
- [Executor Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/executor/index.html)
- [DAG Bundles Documentation](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/dag-bundles.html)

### Vendor and Community
- [Astronomer - Upgrading Checklist](https://www.astronomer.io/blog/upgrading-airflow-2-to-airflow-3-a-checklist-for-2026/)
- [Astronomer - Airflow 3.1](https://www.astronomer.io/blog/introducing-apache-airflow-3-1/)
- [Astronomer - Airflow 3.2](https://www.astronomer.io/blog/apache-airflow-3-2-release/)
- [Astronomer - Executors Explained](https://www.astronomer.io/docs/learn/airflow-executors-explained/)
- [AWS - Migrating Airflow 2.x to 3.x on MWAA](https://aws.amazon.com/blogs/big-data/best-practices-for-migrating-from-apache-airflow-2-x-to-apache-airflow-3-x-on-amazon-mwaa/)
- [DataCamp - Airflow 3.0 Overview](https://www.datacamp.com/blog/apache-airflow-3-0)
- [NextLytics - Airflow Updates 2025](https://www.nextlytics.com/blog/apache-airflow-updates-2025-a-deep-dive-into-features-added-after-3.0)
- [Danube Data Labs - Airflow 3.0 Review](https://danubedatalabs.com/apache-airflow-3-0-new-features-what-hurts-and-should-you-upgrade/)

### AIPs (Airflow Improvement Proposals)
- [AIP-72: Task Execution Interface](https://cwiki.apache.org/confluence/display/AIRFLOW/AIP-72+Task+Execution+Interface+aka+Task+SDK)
- [AIP-61: Hybrid Execution](https://cwiki.apache.org/confluence/display/AIRFLOW/AIP-61+Hybrid+Execution)
- [AIP-69: Edge Executor](https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=301795932)
- [AIP-90: Human in the Loop](https://cwiki.apache.org/confluence/display/AIRFLOW/AIP-90+Human+in+the+loop)
