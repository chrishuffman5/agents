# GCP AI/ML and Data Platform Reference

> Prices are us-central1 unless noted. Verify at https://cloud.google.com/pricing.

## 1. Vertex AI (AI/ML Platform)

Comprehensive ML platform covering the full lifecycle.

### AutoML (No-Code/Low-Code)

- Image classification/detection, text classification/extraction/sentiment, video, tabular.
- Upload data -> train -> deploy. No code required.
- Pricing: $3.15-$13.00/node-hour (training) + prediction compute.

### Custom Training

- Pre-built containers (TensorFlow, PyTorch, XGBoost, scikit-learn) or custom.
- GPUs: T4, V100, A100, H100. TPUs: v2, v3, v4, v5e.
- Distributed training: multi-worker, multi-GPU, parameter servers.
- Hyperparameter tuning: Bayesian optimization via Vizier.

### Model Garden

200+ pre-trained and open models:
- Foundation: Gemini (1.5 Pro, 1.5 Flash, 2.0), Imagen, Codey, Chirp.
- Open: Llama, Mistral, Gemma.
- One-click deployment or fine-tuning.

### Prediction

- **Online:** Real-time, auto-scaling endpoints. Pay per vCPU/GPU-hour while running.
- **Batch:** Large datasets asynchronously. Cost-optimized.
- Traffic splitting for A/B testing and canary deployments.

### MLOps

- **Pipelines:** Managed Kubeflow/TFX pipelines.
- **Experiments:** Track parameters, metrics, artifacts.
- **Model Registry:** Version, stage, govern models.
- **Feature Store:** Managed feature engineering and serving.
- **Model Monitoring:** Data drift, prediction drift detection.

### Pricing Summary

| Component | Cost |
|-----------|------|
| AutoML training | $3.15-$13.00/node-hour |
| Gemini API | $0.075-$5.00/M tokens |
| Prediction endpoints | Per allocated resources |
| Storage | $0.023/GB/month |

---

## 2. TPUs (Tensor Processing Units -- Unique to GCP)

Custom ASICs designed for ML workloads:
- **TPU v5e:** Cost-efficient inference and small-medium training. $1.20/chip/hr on-demand, $0.48/chip/hr 3yr CUD.
- **TPU v5p:** Large-scale training, up to 8960 chips per pod.
- **TPU v4:** Mature, well-supported, pod-scale training.
- vs GPUs: TPUs excel at large matrix operations (transformers). GPUs more flexible (custom CUDA kernels, diverse architectures).
- Multislice training: span jobs across TPU slices for massive parallelism.

---

## 3. Pub/Sub (Messaging)

### Standard Pub/Sub

Fully managed, globally distributed messaging:
- Publisher -> Topic -> Subscription -> Subscriber.
- Push (HTTP), Pull (poll), BigQuery (direct write) subscriptions.
- At-least-once delivery. Exactly-once with ordering key.
- Retention: 7 days default, up to 31 days.

### Pricing

- Messages: $0.04/GB (after 10 GB free/month).
- Seek (replay): $0.006/GB scanned.
- Minimum 1 KB per message for billing.

### Pub/Sub Lite (Cost-Optimized)

- Zonal (not global): lower availability, lower cost.
- Reserved throughput: $0.006/MiB/hr (publish), $0.003/MiB/hr (subscribe).
- 5-10x cheaper than standard for high-volume, latency-tolerant workloads.

---

## 4. Dataflow (Stream/Batch Processing)

Managed Apache Beam runner (unified batch + stream):
- Autoscaling workers, exactly-once processing.
- Streaming Engine: offloads shuffle to managed service (reduces worker cost).
- FlexRS: batch jobs on Spot VMs (40% savings).
- Pricing: vCPU $0.056/hr, memory $0.003557/GB/hr, Streaming Engine $0.018/hr.
- vs Dataproc (Spark): Dataflow = fully managed, Beam SDK. Dataproc = managed Spark/Hadoop, Spark ecosystem.

---

## 5. Dataproc (Managed Spark/Hadoop)

- Managed Spark, Hadoop, Flink, Presto.
- 90-second cluster startup.
- Pricing: $0.01/vCPU/hr premium on Compute Engine costs.
- **Dataproc Serverless:** Submit Spark jobs without cluster management.
- Cost optimization: preemptible secondary workers, autoscaling, ephemeral clusters (store data in GCS).

---

## 6. Data Fusion (Visual ETL/ELT)

- Based on CDAP (open-source). 200+ connectors.
- Editions: Developer ($0.35/hr), Basic ($1.80/hr), Enterprise ($4.20/hr).
- For enterprise ETL with visual drag-and-drop. For code-first, prefer Dataflow/Dataproc.

---

## 7. Composer (Managed Apache Airflow)

- Workflow orchestration with DAGs.
- Composer 2: auto-scaling, pay-per-use compute.
- Minimum ~$300-400/month.
- For complex pipeline orchestration with scheduling, dependencies, monitoring.

---

## 8. Eventarc (Event Routing)

- Unified eventing for GCP. 130+ source services.
- Sources: Google Cloud services, Pub/Sub, third-party (Cloud Audit Logs).
- Targets: Cloud Run, Cloud Functions (2nd gen), GKE, Workflows.
- No separate Eventarc charge (pay for underlying services).

---

## 9. Cloud Build (CI/CD)

- Serverless CI/CD. Build steps as Docker containers.
- Triggers: GitHub, Cloud Source, Bitbucket, webhook, Pub/Sub.
- Private pools for VPC access.
- Pricing: $0.003/build-minute (first 120 min/day free).

---

## 10. Artifact Registry

- Container images + language packages (Docker, Maven, npm, Python, Go, Helm, Apt, Yum).
- Replaces Container Registry (GCR).
- Remote repositories: proxy upstream (Docker Hub, npm, Maven Central).
- Vulnerability scanning.
- Pricing: $0.10/GB/month + egress.

---

## 11. Cloud Monitoring and Logging

### Monitoring

- Metrics, dashboards, alerting. Managed Prometheus.
- Uptime checks: free for up to 1M/month.
- Alerting: email, PagerDuty, Slack, Pub/Sub, webhooks.
- Pricing: first 150 MB metrics free, then $0.258/MB.

### Logging

- Centralized for all GCP services.
- Log Router: route to Cloud Storage, BigQuery, Pub/Sub, Splunk.
- Log Analytics: SQL-based (backed by BigQuery).
- Pricing: $0.50/GiB ingestion (first 50 GiB/project free). Retention free up to 30 days.
- Cost optimization: exclude verbose logs at router, downsample.

### Trace and Profiler

- Cloud Trace: distributed tracing, $0.20/M spans. OpenTelemetry compatible.
- Cloud Profiler: continuous CPU/heap profiling. Free.

---

## 12. Workflows (Serverless Orchestration)

- YAML/JSON workflow definitions. HTTP callbacks, conditionals, parallel execution.
- 200+ Google Cloud API connectors + external HTTP.
- Pricing: $0.01/1K internal steps, $0.025/1K external steps.
- Like AWS Step Functions. For multi-service coordination, approvals, data pipelines.

---

## 13. Cloud Tasks

- HTTP and App Engine task targets.
- Rate limiting, retry, deduplication, delay (up to 30 days).
- $0.40/M tasks (first 1M free/month).
- vs Pub/Sub: Tasks = directed work dispatch. Pub/Sub = broadcast to multiple subscribers.
