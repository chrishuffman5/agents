# Cross-Cloud Service Equivalence Tables

> Complete mapping of equivalent services across AWS, Azure, and GCP. Use for migration planning, multi-cloud architecture, and cloud selection by service category.

---

## Compute Services

| Category | AWS | Azure | GCP |
|----------|-----|-------|-----|
| Virtual Machines | EC2 | Virtual Machines | Compute Engine |
| Managed Kubernetes | EKS | AKS | GKE |
| Containers (serverless) | Fargate | Container Apps | Cloud Run |
| Containers (managed) | ECS | Container Instances | -- |
| Functions (serverless) | Lambda | Functions | Cloud Functions |
| Batch compute | AWS Batch | Batch | Batch |
| Spot/preemptible VMs | Spot Instances | Spot VMs | Spot VMs |
| Bare metal | Outposts (bare metal) | Bare Metal Instances | Bare Metal Solution |
| VMware hosting | VMware Cloud on AWS | Azure VMware Solution | Google Cloud VMware Engine |
| Desktop as a service | WorkSpaces | Azure Virtual Desktop | -- |
| App hosting (PaaS) | Elastic Beanstalk | App Service | App Engine |

---

## Storage Services

| Category | AWS | Azure | GCP |
|----------|-----|-------|-----|
| Object storage | S3 | Blob Storage | Cloud Storage |
| Block storage | EBS | Managed Disks | Persistent Disks |
| File storage (NFS) | EFS | Azure Files / NetApp Files | Filestore |
| File storage (SMB) | FSx for Windows | Azure Files | -- |
| Archive storage | S3 Glacier / Glacier Deep Archive | Blob Archive Tier | Archive Storage |
| Hybrid storage | Storage Gateway | StorSimple / File Sync | -- |
| Managed Lustre | FSx for Lustre | Managed Lustre | -- |
| Disk cache | Instance Store | Temp Disk / Ultra Disk | Local SSD |

---

## Database Services

| Category | AWS | Azure | GCP |
|----------|-----|-------|-----|
| Managed RDBMS | RDS (MySQL, PostgreSQL, MariaDB, Oracle, SQL Server) | Azure SQL, Azure Database for MySQL/PostgreSQL/MariaDB | Cloud SQL (MySQL, PostgreSQL, SQL Server) |
| Cloud-native RDBMS | Aurora (MySQL/PostgreSQL compatible) | Azure SQL Hyperscale | AlloyDB (PostgreSQL compatible) |
| Globally distributed DB | Aurora Global Database | Cosmos DB | Spanner |
| NoSQL document | DocumentDB (MongoDB-compatible) | Cosmos DB (multi-model) | Firestore |
| NoSQL key-value | DynamoDB | Cosmos DB (Table API) / Table Storage | Bigtable |
| In-memory cache | ElastiCache (Redis/Memcached) | Azure Cache for Redis | Memorystore |
| Data warehouse | Redshift | Synapse Analytics | BigQuery |
| Time-series | Timestream | Azure Data Explorer | -- (use BigQuery or Bigtable) |
| Graph | Neptune | Cosmos DB (Gremlin API) | -- (use Neo4j on GKE) |
| Ledger / Immutable | QLDB | Confidential Ledger | -- |

---

## Networking Services

| Category | AWS | Azure | GCP |
|----------|-----|-------|-----|
| Virtual network | VPC | VNet | VPC |
| Subnets | Subnets (per-AZ) | Subnets (regional) | Subnets (regional) |
| Load balancer (L7) | ALB | Application Gateway | HTTP(S) Load Balancer |
| Load balancer (L4) | NLB | Azure Load Balancer | TCP/UDP Load Balancer |
| DNS | Route 53 | Azure DNS | Cloud DNS |
| CDN | CloudFront | Front Door / CDN | Cloud CDN |
| API Gateway | API Gateway | API Management | API Gateway / Apigee |
| VPN | Site-to-Site VPN | VPN Gateway | Cloud VPN |
| Dedicated connection | Direct Connect | ExpressRoute | Cloud Interconnect |
| Service mesh | App Mesh | -- (use Istio on AKS) | Traffic Director / Istio on GKE |
| Private link to services | PrivateLink | Private Endpoint | Private Service Connect |
| DDoS protection | Shield | DDoS Protection | Cloud Armor |
| Firewall | Network Firewall | Azure Firewall | Cloud Firewall |
| Transit/hub networking | Transit Gateway | Virtual WAN | Network Connectivity Center |
| Global load balancing | Global Accelerator | Front Door | Global HTTP(S) LB (native) |

---

## Security and Identity Services

| Category | AWS | Azure | GCP |
|----------|-----|-------|-----|
| Identity and access | IAM (policies + roles) | Entra ID + Azure RBAC | IAM (policies + roles) |
| Directory service | Directory Service (AD) | Entra ID (native AD) | Cloud Identity |
| Secrets management | Secrets Manager | Key Vault (secrets) | Secret Manager |
| Key management | KMS | Key Vault (keys) | Cloud KMS |
| Certificate management | ACM | Key Vault (certificates) / App Service Certs | Certificate Manager |
| Threat detection | GuardDuty | Defender for Cloud | Security Command Center |
| Security posture | Security Hub | Defender for Cloud | Security Command Center |
| WAF | WAF | WAF (via Front Door/App Gateway) | Cloud Armor |
| Managed identities | IAM Roles (for services) | Managed Identities | Service Accounts + Workload Identity |
| Policy enforcement | Organizations SCPs + Config | Azure Policy + Blueprints | Organization Policy |
| Vulnerability scanning | Inspector | Defender Vulnerability Management | Container Analysis + Web Security Scanner |

---

## Serverless and Event-Driven Services

| Category | AWS | Azure | GCP |
|----------|-----|-------|-----|
| Functions | Lambda | Functions | Cloud Functions |
| Workflow orchestration | Step Functions | Logic Apps / Durable Functions | Workflows |
| Event bus | EventBridge | Event Grid | Eventarc |
| Message queue | SQS | Queue Storage / Service Bus Queues | Cloud Tasks |
| Pub/sub messaging | SNS | Service Bus Topics / Event Grid | Pub/Sub |
| Streaming | Kinesis Data Streams | Event Hubs | Pub/Sub + Dataflow |
| Scheduled tasks | EventBridge Scheduler | Timer-triggered Functions / Logic Apps | Cloud Scheduler |

---

## AI/ML Services

| Category | AWS | Azure | GCP |
|----------|-----|-------|-----|
| ML platform | SageMaker | Azure Machine Learning | Vertex AI |
| Pre-built AI APIs | Rekognition, Comprehend, Translate, Polly, Textract | Cognitive Services (Vision, Language, Speech) | Vision AI, Natural Language, Speech-to-Text, Translation |
| LLM hosting | Bedrock | Azure OpenAI Service | Vertex AI (Model Garden) |
| Custom hardware (ML) | Inferentia / Trainium | -- | TPUs |
| AutoML | SageMaker Autopilot | Azure AutoML | Vertex AI AutoML |
| MLOps | SageMaker Pipelines | Azure ML Pipelines | Vertex AI Pipelines |
| Notebooks | SageMaker Studio | Azure ML Notebooks | Vertex AI Workbench / Colab Enterprise |

---

## Data and Analytics Services

| Category | AWS | Azure | GCP |
|----------|-----|-------|-----|
| Data warehouse | Redshift | Synapse Analytics | BigQuery |
| ETL / Data integration | Glue | Data Factory | Dataflow / Dataproc |
| Data lake storage | S3 + Lake Formation | Data Lake Storage Gen2 | Cloud Storage + BigLake |
| Stream processing | Kinesis Data Analytics | Stream Analytics | Dataflow |
| Data catalog | Glue Data Catalog | Purview | Data Catalog / Dataplex |
| BI / Visualization | QuickSight | Power BI | Looker |
| Hadoop/Spark managed | EMR | HDInsight | Dataproc |
| Search | OpenSearch Service | Cognitive Search | -- (use Elastic on GKE) |

---

## DevOps and IaC Services

| Category | AWS | Azure | GCP |
|----------|-----|-------|-----|
| IaC (native) | CloudFormation | ARM Templates / Bicep | Deployment Manager (deprecated) / Config Connector |
| IaC (cross-cloud) | Terraform, Pulumi, CDK | Terraform, Pulumi, Bicep | Terraform, Pulumi |
| CI/CD | CodePipeline + CodeBuild | Azure DevOps / GitHub Actions | Cloud Build |
| Container registry | ECR | ACR | Artifact Registry |
| Artifact repository | CodeArtifact | Azure Artifacts | Artifact Registry |
| Monitoring | CloudWatch | Monitor + Log Analytics | Cloud Monitoring + Cloud Logging |
| Tracing | X-Ray | Application Insights | Cloud Trace |
| Config management | Systems Manager | Automation / Update Management | OS Config |

---

## Pricing Model Comparison

### Compute Discount Mechanisms

| Mechanism | AWS | Azure | GCP |
|-----------|-----|-------|-----|
| Auto-discount for sustained use | -- | -- | SUDs: up to 30% off for VMs running 25%+ of month |
| Reserved (1-year) | Up to 40% off | Up to 40% off | CUDs: up to 37% off |
| Reserved (3-year) | Up to 60% off | Up to 60% off | CUDs: up to 55% off |
| Flexible commitment | Savings Plans (compute family) | Savings Plans (compute) | CUDs (compute or resource-based) |
| Bring your own license | -- | Azure Hybrid Benefit (Windows + SQL): up to 85% savings | -- |
| Custom machine types | -- | -- | Yes -- pay for exact vCPU/RAM needed |
| Spot/preemptible | Up to 90% off (2-min warning) | Up to 90% off (30-sec notice) | Up to 91% off (30-sec notice) |

### Network Egress Pricing

| Tier | AWS | Azure | GCP |
|------|-----|-------|-----|
| Free egress/month | 100 GB | 100 GB | 200 GB |
| First 10 TB/mo | $0.09/GB | $0.087/GB | $0.12/GB (premium) / $0.085/GB (standard) |
| Same-region cross-AZ | $0.01/GB each direction | Free | Free |

**Key insight:** Azure and GCP do not charge for cross-AZ traffic within a region. AWS charges $0.01/GB each direction, which compounds for distributed architectures.

### Storage Pricing (Hot Tier, per GB/month)

| Metric | AWS S3 Standard | Azure Blob Hot | GCP Standard |
|--------|----------------|----------------|--------------|
| Storage | $0.023/GB | $0.018/GB | $0.020/GB |
| GET (per 1K) | $0.0004 | $0.004 | $0.004 |
| PUT (per 1K) | $0.005 | $0.05 | $0.05 |

### Support Plan Comparison

| Tier | AWS | Azure | GCP |
|------|-----|-------|-----|
| Business/Standard | $100/mo or 5-10% of usage | $100/mo | $500/mo (Enhanced) |
| Enterprise/Premium | $15K/mo or 3-10% of usage | Custom pricing (Unified) | $12.5K/mo (Premium) |
| Critical response SLA | <15 min | <15 min | <15 min |
| TAM included | Enterprise | Unified (CSAM) | Premium |

### Free Tier Comparison

| Aspect | AWS | Azure | GCP |
|--------|-----|-------|-----|
| Duration | 12-month + always-free | 12-month + always-free | 90-day $300 credit + always-free |
| Functions (always free) | 1M invocations/mo | 1M executions/mo | 2M invocations/mo |
| Always-free compute | -- | -- | 1 e2-micro (US regions) |
