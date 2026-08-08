# Deployment, A2A, and live streaming reference

Read before deploying an ADK agent anywhere, exposing/consuming an agent over A2A, or building a voice/video agent.

## Deployment options

> Source: https://adk.dev/deploy/

1. **Agent Runtime on Agent Platform** — "A fully managed auto-scaling service on Google Cloud specifically designed for deploying, managing, and scaling AI agents built with frameworks such as ADK." This is ADK's current name for what was previously called Agent Engine / Vertex AI Agent Engine.
2. **Cloud Run** — Google Cloud's managed auto-scaling compute; agents run as container-based applications.
3. **Google Kubernetes Engine (GKE)** — managed Kubernetes; recommended when you need greater control or plan to run open models.
4. **Custom container deployment** — package agents into container images for any container-compatible infrastructure (Docker, Podman, disconnected systems).

## Cloud Run

> Source: https://adk.dev/deploy/cloud-run/

```bash
export GOOGLE_CLOUD_PROJECT="your-gcp-project-id"
export GOOGLE_CLOUD_LOCATION="us-central1"
export AGENT_PATH="./capital_agent"
export SERVICE_NAME="capital-agent-service"
```

**`adk deploy cloud_run` (Python, recommended path)**:

```bash
adk deploy cloud_run \
  --project=$GOOGLE_CLOUD_PROJECT \
  --region=$GOOGLE_CLOUD_LOCATION \
  --service_name=$SERVICE_NAME \
  --app_name=capital_agent \
  --with_ui \
  $AGENT_PATH
```

Key flags: `--project` (required), `--region` (required), `--service_name`, `--app_name`, `--with_ui` (deploy the web interface), `--session_service_uri` (e.g. `sqlite://`, `agentengine://`), `--artifact_service_uri`.

Raw `gcloud` flags pass through after `--`:

```bash
adk deploy cloud_run --project=$GOOGLE_CLOUD_PROJECT --region=$GOOGLE_CLOUD_LOCATION \
  $AGENT_PATH -- --no-allow-unauthenticated --min-instances=2
```

**Manual `gcloud` path** — project layout:

```
your-project-directory/
├── capital_agent/
│   ├── __init__.py
│   └── agent.py
├── main.py
├── requirements.txt
└── Dockerfile
```

`main.py`:

```python
from google.adk.cli.fast_api import get_fast_api_app

app = get_fast_api_app(
    agents_dir=AGENT_DIR,
    session_service_uri="sqlite+aiosqlite:///./sessions.db",
    allow_origins=["*"],
    web=True
)
```

`requirements.txt` needs `google-adk`. `Dockerfile`:

```dockerfile
FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port $PORT"]
```

```bash
gcloud run deploy capital-agent-service \
  --source . \
  --region $GOOGLE_CLOUD_LOCATION \
  --project $GOOGLE_CLOUD_PROJECT \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT,GOOGLE_CLOUD_LOCATION=$GOOGLE_CLOUD_LOCATION"
```

`allow_origins=["*"]` and `--allow-unauthenticated` come straight from the docs' walkthrough. Neither belongs in a production deployment — narrow both before shipping.

**TypeScript** (run from the directory containing `package.json`):

```bash
npx adk deploy cloud_run --project=$GOOGLE_CLOUD_PROJECT --region=$GOOGLE_CLOUD_LOCATION \
  --service_name=$SERVICE_NAME --with_ui
```

**Go**:

```bash
go build ./cmd/adkgo
./adkgo deploy cloudrun -p $GOOGLE_CLOUD_PROJECT -r $GOOGLE_CLOUD_LOCATION -s $SERVICE_NAME \
  --proxy_port=8081 --server_port=8080 -e ./main.go --a2a --api --webui
```

**Java** — `pom.xml` dependency `com.google.adk:google-adk:1.6.0`; the Dockerfile builds via Maven (`mvn compile exec:java ...`); deploy with the same `gcloud run deploy --source .` pattern as Python.

**Smoke-testing a deployed agent**:

```bash
export TOKEN=$(gcloud auth print-identity-token)
export APP_URL="https://your-service-name.a.run.app"

curl -X GET -H "Authorization: Bearer $TOKEN" $APP_URL/list-apps

curl -X POST -H "Authorization: Bearer $TOKEN" $APP_URL/run_sse \
  -H "Content-Type: application/json" \
  -d '{"app_name":"capital_agent","user_id":"user_123","session_id":"session_abc","new_message":{"role":"user","parts":[{"text":"What is the capital of Canada?"}]},"streaming":false}'
```

## Agent Runtime (Agent Engine)

> Source: https://adk.dev/deploy/agent-runtime/deploy/
> Source: https://adk.dev/deploy/

```bash
adk deploy agent_engine \
  --project=$PROJECT_ID \
  --region=$LOCATION_ID \
  --display_name="Agent Name" \
  <project_folder>
```

This "packages your code, builds it into a container, and deploys it to the managed Agent Runtime service."

**Prerequisites**: Agent Platform API enabled, Cloud Resource Manager API enabled, `gcloud auth login` plus `gcloud auth application-default login`, and a project folder containing `agent.py` and its dependencies.

**Language support as of 2026-08-05: Python and Go v1.2.0+.** For Python, the deployed package does **not** include the ADK API server or ADK web UI libraries; for Go, it **does** include the dedicated ADK API server. Set expectations accordingly — a Python Agent Runtime deployment has no `adk web`.

Access a deployed agent via the Vertex AI SDK:

```python
import vertexai
agent_engine = vertexai.agent_engines.get(
  'projects/[PROJECT_ID]/locations/[LOCATION]/reasoningEngines/[RESOURCE_ID]'
)
```

REST query endpoint:

```
https://[LOCATION]-aiplatform.googleapis.com/v1/projects/[PROJECT_ID]/locations/[LOCATION]/reasoningEngines/[RESOURCE_ID]:query
```

The `reasoningEngines` resource path is the legacy naming surfacing through the new product name — expect it in IAM policies and logs.

## GKE

> Source: https://adk.dev/deploy/gke/

```bash
export GOOGLE_CLOUD_PROJECT=your-project-id
export GOOGLE_CLOUD_LOCATION=us-central1
gcloud services enable container.googleapis.com artifactregistry.googleapis.com \
  cloudbuild.googleapis.com aiplatform.googleapis.com
```

1. **Cluster**:

```bash
gcloud container clusters create-auto adk-cluster \
    --location=$GOOGLE_CLOUD_LOCATION --project=$GOOGLE_CLOUD_PROJECT
gcloud container clusters get-credentials adk-cluster \
    --location=$GOOGLE_CLOUD_LOCATION --project=$GOOGLE_CLOUD_PROJECT
```

2. **Artifact Registry**:

```bash
gcloud artifacts repositories create adk-repo \
    --repository-format=docker --location=$GOOGLE_CLOUD_LOCATION
```

3. **Build and push** (Cloud Build, Python):

```bash
gcloud builds submit \
    --tag $GOOGLE_CLOUD_LOCATION-docker.pkg.dev/$GOOGLE_CLOUD_PROJECT/adk-repo/adk-agent:latest \
    --project=$GOOGLE_CLOUD_PROJECT .
```

4. **Workload Identity** for Agent Platform access:

```bash
kubectl create serviceaccount adk-agent-sa
gcloud projects add-iam-policy-binding projects/${GOOGLE_CLOUD_PROJECT} \
    --role=roles/aiplatform.user \
    --member="principal://iam.googleapis.com/projects/${GOOGLE_CLOUD_PROJECT_NUMBER}/locations/global/workloadIdentityPools/${GOOGLE_CLOUD_PROJECT}.svc.id.goog/subject/ns/default/sa/adk-agent-sa"
```

5. **Deploy**:

```bash
kubectl apply -f deployment.yaml
kubectl get pods -l=app=adk-agent
kubectl get svc adk-agent
```

The Dockerfile is the same pattern as Cloud Run. **Automated alternative**: `adk deploy gke` (Python only) handles containerization, registry push, and manifest generation.

Kubernetes runtime depth beyond this path — networking, autoscaling, security contexts — is the containers plugin, not this skill.

## A2A (Agent2Agent) protocol

> Source: https://adk.dev/a2a/intro/

"The Agent2Agent (A2A) Protocol is the standard that allows [specialized] agents to communicate with each other" across network boundaries.

- **Exposing** — convert an existing ADK agent into an `A2AServer` to make it reachable by remote agents.
- **Consuming** — use a `RemoteA2aAgent` component to connect to remote A2A-compatible agents.

**Use A2A when**: integrating separate standalone services maintained by different teams; connecting agents across different languages or frameworks; building microservice architectures needing network-based communication; enforcing formal API contracts between components.

**Avoid A2A when**: it is just internal code organization within a single agent; high-frequency low-latency operations needing shared memory access; simple helper functions better suited as local components.

**Capabilities in ADK's A2A implementation**:

1. **Reasoning** — preserves model reasoning traces across agent communications.
2. **Long-running tools** — tracks extended tool operations to prevent timeouts.
3. **Artifacts** — transfers file artifacts between distributed agents.

Once configured, calling a remote agent feels like calling a local function; ADK manages the network complexity internally.

Per-language quickstart pages (sitemap-listed, contents not fetched): `/a2a/quickstart-consuming/`, `/a2a/quickstart-consuming-go/`, `/a2a/quickstart-consuming-java/`, `/a2a/quickstart-exposing/`, `/a2a/quickstart-exposing-go/`, `/a2a/quickstart-exposing-java/`, plus `/a2a/a2a-extension/`.

## Live / streaming agents

> Source: https://adk.dev/live/

The "ADK Gemini Live API Toolkit" enables "low-latency bidirectional voice and video interaction" — "natural, human-like voice conversations" where users can interrupt agent responses with voice commands.

**Bidirectional streaming architecture**: agents process text, audio, and video input; produce text and audio output; support real-time interactive communication.

Core pieces:

- **`RunConfig` streaming mode** — configures response modalities and streaming behavior (detail on `/live/configuration/`, not fetched).
- **`run_live()`** — the core API for processing the stream of events; handles text/audio/transcriptions, executes tools automatically, supports multi-agent workflows.
- **`LiveRequestQueue`** — manages upstream message flow: send text, audio, and video content plus activity signals, with concurrent message handling.

Documented applications: voice-activated shopping assistants with camera input, video-stream monitoring with agent reactions, real-time stock-price tracking, custom interactive agents via FastAPI.

Sitemap sub-pages under `/live/`: configuration, streaming-tools, dev guides, get-started — a five-part guide covering fundamentals, message sending, event handling, configuration, and multimedia integration. Their contents were not fetched.

## Unverified

`https://adk.dev/deploy/agent-runtime/agents-cli/` — the accelerated "Agents CLI" deployment path with CI/CD and infrastructure-as-code — is named in the docs but was not fetched. Do not describe its commands.

## Sources

- https://adk.dev/deploy/
- https://adk.dev/deploy/cloud-run/
- https://adk.dev/deploy/gke/
- https://adk.dev/deploy/agent-runtime/deploy/
- https://adk.dev/a2a/intro/
- https://adk.dev/live/

Fetched: 2026-08-05
