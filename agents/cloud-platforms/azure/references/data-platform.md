# Azure Data Platform Reference

> Prices are US East, pay-as-you-go unless noted. Verify at https://azure.microsoft.com/pricing/.

## 1. Azure Data Factory

Cloud ETL/ELT orchestration with 100+ connectors.

### Pricing Components

| Component | Unit | Cost |
|-----------|------|------|
| Activity/pipeline runs | Per 1,000 | $1.00 |
| Data movement (Azure IR) | Per DIU-hour | $0.25 |
| Data movement (Self-hosted IR) | Per hour | $0.10 |
| Mapping Data Flow | Per vCore-hour | $0.256 |
| Data Flow debug | Per vCore-hour | $0.256 (8-core min = $2.05/hr) |

### Integration Runtimes

- **Azure IR:** Managed compute. Auto-resolving or fixed region. Cloud-to-cloud.
- **Self-Hosted IR:** On your machine/VM. Required for on-prem data, private networks. No ADF compute charge (you pay for the VM).
- **Azure-SSIS IR:** Managed SSIS for legacy packages. ~$0.84/hr for 2 vCores.

### Mapping Data Flows vs Copy Activity

- **Copy Activity:** Move data as-is. DIU-based pricing. No transformation.
- **Mapping Data Flows:** Spark-based visual transforms. $0.256/vCore-hour (min 8 cores = $2.05/hr).
- Use Copy for extract-load. Use Data Flows only for transformation logic. For sustained complex transforms, Synapse Spark or Databricks is often cheaper.

### Data Factory vs Synapse Pipelines

Synapse Pipelines = same ADF engine inside a Synapse workspace. If you already have Synapse, use its pipelines. Standalone ADF is better without Synapse analytics.

---

## 2. Synapse Analytics

Unified analytics: SQL warehousing, Spark processing, and data integration.

### Components and Pricing

| Component | Model | Cost | Auto-pause |
|-----------|-------|------|------------|
| Dedicated SQL Pool | DWU-hours | $1.20/DWU-hr (DW100c) | Manual only |
| Serverless SQL Pool | Per TB scanned | $5.00/TB (first 1 TB/mo free) | Always on (per-query) |
| Spark Pool | vCore-hours | $0.16/vCore-hr | Yes (5-min default) |

### Dedicated SQL Pools

- DWU bundles compute, memory, IO. Range: DW100c to DW30000c.
- Scale up/down in ~5 minutes. Pause when not in use -- pay only storage ($23/TB/month).
- Cost example: DW1000c x 12 hrs/day x 22 days = ~$3,168/mo. Pausing nights/weekends saves ~60%.

### Serverless SQL Pool

- Query Parquet, CSV, JSON, Delta Lake in Data Lake Gen2 directly.
- $5/TB scanned. First 1 TB/month free.
- **Cost optimization:** Store data in Parquet with proper partitioning. Reduces scanned data by 90-99% vs CSV.

### Spark Pools

- Auto-pause (default 5 min idle), auto-scale. Delta Lake built-in.
- $0.16/vCore-hour. Medium node (8 vCores) = $1.28/hr.

### Synapse vs Databricks

| Factor | Synapse | Databricks |
|--------|---------|------------|
| Primary workload | SQL analytics, BI | Data engineering, ML, streaming |
| Integration | Tight Azure (Power BI, ADF) | Multi-cloud, open ecosystem |
| ML/AI | Basic (SparkML) | MLflow, Feature Store, Model Serving |
| Spark cost | $0.16/vCore-hr (auto-pause) | ~$0.20-0.40/DBU total |

Synapse when SQL analytics is primary and Azure integration is key. Databricks for data engineering, ML, and multi-cloud.

---

## 3. Event Hubs (Streaming Ingestion)

High-throughput real-time event streaming:

| Tier | Unit | $/unit/hr | Throughput | Max Partitions |
|------|------|-----------|------------|----------------|
| Basic | TU | $0.015 | 1 TU, 1 consumer group | 32 |
| Standard | TU | $0.030 | 1-40 TU, 20 consumer groups | 32 |
| Premium | PU | $1.653 | 1-16 PU (~5-10 TU/PU) | 100 |
| Dedicated | CU | ~$6.849 | 1+ CU, unlimited | 1024 |

1 TU = 1 MB/s ingress + 2 MB/s egress + 1,000 events/s.

**Capture:** Auto-write to Blob/ADLS in Avro ($0.10/hr per window). Zero-code streaming-to-lake.

**Kafka compatibility:** Standard+ exposes Kafka endpoint. Existing producers/consumers connect without code changes.

---

## 4. Service Bus (Enterprise Messaging)

| Feature | Basic | Standard | Premium |
|---------|-------|----------|---------|
| Queues | Yes | Yes | Yes |
| Topics/Subscriptions | No | Yes | Yes |
| Sessions (FIFO) | No | No | Yes |
| Transactions | No | No | Yes |
| Max message size | 256 KB | 256 KB | 100 MB |
| Pricing | $0.05/M ops | $0.0135/hr + $0.01/M ops | $1.014/MU/hr |

Key vs Event Hubs:
- **Service Bus:** Message locking, completion, scheduling, dead-lettering, duplicate detection.
- **Event Hubs:** Competing consumers with offset tracking, event replay (1-90 day retention).

---

## 5. Event Grid (Event Routing)

Lightweight pub/sub for reactive architectures:
- $0.60/million events (first 100K/month free).
- Sub-second delivery. At-least-once.
- Sources: Azure services, custom topics, partner events.
- Handlers: Functions, Logic Apps, Webhooks, Event Hubs, Service Bus, Storage Queues.

---

## 6. Messaging Selection Matrix

| Scenario | Service |
|----------|---------|
| IoT telemetry (millions/sec) | Event Hubs |
| Log aggregation, streaming analytics | Event Hubs |
| Order processing with FIFO | Service Bus (sessions) |
| Microservice async communication | Service Bus (topics) |
| React to Azure resource changes | Event Grid |
| Blob upload triggers pipeline | Event Grid -> Function/Event Hub |
| Real-time dashboards | Event Hubs -> Stream Analytics/Spark |
