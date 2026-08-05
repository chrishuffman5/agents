# Amazon Bedrock

Read when you are calling models through `bedrock-runtime`/`bedrock-mantle`, debugging entitlement or IAM, choosing between cross-region inference and Provisioned Throughput, wiring Guardrails, or keeping traffic off the public internet.

Snapshot of AWS and Anthropic docs on 2026-08-05. Model IDs, region lists, and prices move — re-verify against the URLs at the bottom.

## Inference APIs and endpoints

> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/conversation-inference.html
> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters.html
> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/inference.html

Bedrock exposes four families of inference operations on `bedrock-runtime`, plus a newer `bedrock-mantle` endpoint.

| API | Shape | Use when |
|---|---|---|
| `Converse` / `ConverseStream` | One model-agnostic request/response for every model that supports "messages"; model-specific params via `additionalModelRequestFields` | Default for new conversational apps. Tool use and Guardrails are implemented here. |
| `InvokeModel` / `InvokeModelWithResponseStream` | Provider-specific JSON body per model family (Nova, Titan, Anthropic, AI21, Cohere, DeepSeek, Luma, Meta, Mistral, OpenAI, Stability, TwelveLabs, Writer Palmyra) | You need control Converse does not expose, or a feature Converse has not surfaced yet |
| `bedrock-mantle` endpoint | OpenAI-style **Responses API**, **Chat Completions API**, and an **Anthropic Messages API** served directly | Porting OpenAI- or Anthropic-shaped code with minimal edits |

AWS's own guidance: "write code once, use it with different models" — Converse first, InvokeModel as the escape hatch.

Two behaviors that surprise people:

- With **Mistral AI and Meta** models, Converse embeds your input into a model-specific prompt template to enable multi-turn conversation. InvokeModel does not do this transformation. Output differences between the two APIs on those families are expected.
- **PDF handling**: works through both APIs, but Converse users must enable **citations** to get visual PDF analysis (charts, images, layout). Without citations you get basic text extraction only. Use InvokeModel when you need visual analysis without forced citations.

API restrictions documented by AWS apply identically to `InvokeModel`, `InvokeModelWithResponseStream`, `Converse`, and `ConverseStream`.

## IAM: minimum policies per endpoint

> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/inference.html
> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/security-iam.html

`bedrock-runtime` (Converse + Invoke):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "ModelInvocationPermissions",
    "Effect": "Allow",
    "Action": [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:GetInferenceProfile",
      "bedrock:ListInferenceProfiles",
      "bedrock:RenderPrompt",
      "bedrock:GetCustomModel",
      "bedrock:ListCustomModels",
      "bedrock:GetImportedModel",
      "bedrock:ListImportedModels",
      "bedrock:GetProvisionedModelThroughput",
      "bedrock:ListProvisionedModelThroughputs",
      "bedrock:GetGuardrail",
      "bedrock:ListGuardrails",
      "bedrock:ApplyGuardrail"
    ],
    "Resource": "*"
  }]
}
```

`bedrock-mantle` (Responses / Chat Completions / Messages):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "MantleInferencePermissions",
    "Effect": "Allow",
    "Action": [
      "bedrock-mantle:CreateInference",
      "bedrock-mantle:GetProject",
      "bedrock-mantle:ListProjects",
      "bedrock-mantle:ListTagsForResources"
    ],
    "Resource": "*"
  }]
}
```

Managed-policy mapping: `AmazonBedrockFullAccess` covers `bedrock-runtime`; `AmazonBedrockMantleInferenceAccess` covers `bedrock-mantle`. **They are not interchangeable** — a role with only the former gets denied on mantle.

Bedrock uses standard AWS IAM throughout: identity-based policies, resource-based policies, permissions boundaries, SCPs, RCPs, and session policies, evaluated by normal IAM logic. Programmatic access is SigV4-signed; AWS and Anthropic SDKs sign for you. Prefer IAM roles and IAM Identity Center federation over long-lived user credentials.

Invoke-only access to a single Provisioned Throughput model, with no ability to view or manage the throughput itself:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"],
    "Resource": "arn:aws:bedrock:us-east-1:{{account-id}}:provisioned-model/{{my-provisioned-model}}"
  }]
}
```

Console Playground access additionally needs read actions (`ListFoundationModels`, `ListInferenceProfiles`, `GetFoundationModel`), `sagemaker:ListHubContents` on `arn:aws:sagemaker:*:aws:hub/SageMakerPublicHub`, invoke scoped to both `foundation-model/*` and `inference-profile/*` ARNs, and a Marketplace subscribe grant conditioned on `aws:CalledViaLast: bedrock.amazonaws.com`.

## Model access and entitlement

> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html

As of 2026-08-05 there is **no manual "request access" click-through** for most models — access is enabled by default given correct Marketplace permissions.

Mechanics that cause real incidents:

- **Auto-subscription**: the first invocation of a third-party model in an account starts the AWS Marketplace subscription in the background. It can take **up to 15 minutes**, during which calls transiently succeed or fail with `AccessDeniedException`. Wait it out before rewriting IAM.
- **Prerequisites**: the calling role needs `aws-marketplace:Subscribe`, `aws-marketplace:Unsubscribe`, `aws-marketplace:ViewSubscriptions`; the account needs a valid Marketplace payment method.
- **Anthropic models require a one-time first-time-use (FTU) use-case form** per account, or per AWS Organization management account — company name, website, intended users, industry, use-case description — before first invocation. It does **not** apply to Anthropic models reached via `bedrock-mantle`.
- **EULA by invocation**: first use of a third-party model implicitly accepts that provider's EULA. Organizations that must review EULAs first should block via SCP/IAM, review, then unblock.
- Models from **Amazon, DeepSeek, Mistral AI, Meta, Qwen, and OpenAI are not sold through AWS Marketplace** and have no product IDs, so you cannot scope `aws-marketplace:Subscribe` conditions to them. Use `bedrock:*` deny policies on the model ARN instead.

Programmatic entitlement management (AWS CLI ≥ 2.27.42):

1. `ListFoundationModelAgreementOffers`
2. `PutUseCaseForModelAccess` (Anthropic only, one-time)
3. `CreateFoundationModelAgreement` with the offer token
4. `GetFoundationModelAvailability` — confirm `agreementAvailability: AVAILABLE`, `authorizationStatus: AUTHORIZED`, `entitlementAvailability: AVAILABLE`, `regionAvailability: AVAILABLE`

`DeleteFoundationModelAgreement` removes access, but **invoking the model again silently recreates it**. It is not a control.

**GovCloud (US)**: third-party model access must be enabled separately in *both* the linked commercial account (invoke in `us-east-1`/`us-west-2`) **and** the GovCloud account itself (console, `us-gov-west-1`, manual). Amazon's own models only need enabling in GovCloud.

### Actually blocking a model

> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html
> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/security_iam_id-based-policy-examples.html

Denying `aws-marketplace:Subscribe` does **not** block first invocation, because Bedrock auto-subscribes in the background. Deny the invoke actions on the foundation-model ARN at the SCP or IAM level:

```json
{
  "Version": "2012-10-17",
  "Statement": {
    "Sid": "DenyInference",
    "Effect": "Deny",
    "Action": [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:CreateModelInvocationJob"
    ],
    "Resource": "arn:aws:bedrock:*::foundation-model/{{model-id}}"
  }
}
```

Use `*` for the model ID to deny inference on all foundation models. **Denying `InvokeModel` automatically blocks `Converse` and `StartAsyncInvoke` too.** To stop an identity using a model it already has access to, in any region, deny `bedrock:*` on that model's ARN.

## Cross-region inference profiles

> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html
> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html

An **inference profile** pairs a foundation model with the set of Regions requests may be routed to. Two flavors:

| | Geographic cross-Region inference | Global cross-Region inference |
|---|---|---|
| Data residency | Within a geography (US/EU/APAC) | Any supported commercial AWS Region worldwide |
| Cost | Standard pricing | ~10% cheaper |
| SCP requirement | Allow all destination Regions in the profile | Allow `"aws:RequestedRegion": "unspecified"` |
| Choose for | Data-residency/compliance obligations | Cost optimization |

Facts that change designs:

- **No routing fee.** Price is based on the **source** Region you call from.
- CRIS can route into Regions your account never opted into; manual Region enablement is not required. Prompts/outputs may be transiently stored in those destination Regions for abuse detection.
- All inter-Region traffic stays on the AWS network, encrypted in transit, never the public internet.
- CloudTrail logs cross-Region requests in the **source** Region. Read `additionalEventData.inferenceRegion` to see where a request actually ran.
- **Inference profiles do not support Provisioned Throughput.** CRIS and PT are mutually exclusive purchase paths.
- SCPs and IAM jointly gate routing. If **any** destination Region in the profile is blocked, the whole request fails — partial allowance is not partial success.

### Profile IDs and routing

- System-defined profile ID = **geography prefix + base model ID**, e.g. `us.anthropic.claude-3-haiku-20240307-v1:0`. Observed prefixes: `us`, `eu`, `jp`, `apac`, `global`.
- **Routing differs by source Region for the same profile ID.** `us.anthropic.claude-3-haiku-20240307-v1:0` called from US East (Ohio) can route to `us-east-1`, `us-east-2`, or `us-west-2`; called from US West (Oregon) it can only reach `us-east-1` and `us-west-2`.
- Global profiles' destination list grows over time as AWS adds Regions. Geography-scoped profiles' destination lists are fixed — AWS mints new profile IDs rather than changing existing ones.
- Inspect a profile with `GetInferenceProfile`; the `models` field lists model ARNs from which destination Regions can be read.
- **Application inference profiles** (user-created, for cost tracking and tagging) can be created from most non-embedding models in: ap-northeast-1, ap-northeast-2, ap-south-1, ap-southeast-1, ap-southeast-2, ca-central-1, eu-central-1, eu-west-1, eu-west-2, eu-west-3, sa-east-1, us-east-1, us-east-2, us-gov-east-1, us-west-2.
- Exact profile IDs, source/destination Regions, and Geo scope are documented **per-model on each model's detail page**, not in one master list.

## Provisioned Throughput

> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/prov-throughput.html

PT reserves a guaranteed throughput level for a model at a **fixed hourly cost, billed regardless of usage until deleted**.

- **Required for any customized (fine-tuned) model** — custom models cannot be invoked on-demand at all.
- Sized in **Model Units (MUs)**; each MU guarantees a fixed input tokens/minute and output tokens/minute for a specific model. Exact throughput-per-MU and price-per-MU are **not published** — AWS says contact your account manager.
- Commitment tiers, longer = cheaper hourly: **no commitment** (delete anytime), **1 month** (locked), **6 months** (locked, most discounted).
- Custom models use the **same per-MU pricing as their base model**.
- Workflow: size MUs and term → purchase PT for a base or custom model → invoke against it → modify or delete.

## Pricing structure

> Source: https://aws.amazon.com/bedrock/pricing/

Shape, not current numbers — the per-model figures on AWS's page at fetch time were legacy-model examples and are unsafe to quote:

- **On-demand** per-million-token, varying by provider and model.
- **Batch inference** on selected models at roughly **50% below on-demand**.
- **Provisioned Throughput** hourly, commitment-tiered (AWS's illustrative example: a Cohere Command model at $49.50/hr no-commitment vs $39.60/hr with a 1-month commitment).
- **Knowledge Bases**: ~$5.00/GB-month index storage; ~$1.00 per 1,000 retrieval API calls.
- **Guardrails**: ~$0.15 per 1,000 text units for content filters.
- **Bedrock-integrated web search**: ~$12.00 per 1,000 queries.

Confirm every figure at the pricing page before it reaches a budget.

## Guardrails

> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html

Configurable safeguards on inputs and/or outputs (reasoning-content blocks excluded), **independent of which foundation model is used**:

- **Content filters** — Hate, Insults, Sexual, Violence, Misconduct, Prompt Attack, with per-category strength. **Standard tier** additionally catches harmful content embedded in code (comments, identifiers, string literals); Classic tier does not.
- **Denied topics** — block defined topics in queries or responses; Standard tier extends into code elements.
- **Word filters** — exact-match blocking (profanity presets, competitor names).
- **Sensitive information filters** — probabilistic PII detection/blocking or masking, plus custom regex.
- **Contextual grounding checks** — flag responses ungrounded in the provided source or irrelevant to the query. The RAG hallucination control.
- **Automated Reasoning checks** — validate responses against defined logical rules; surface hallucinations, suggest corrections, highlight unstated assumptions.

Two usage modes: attach a guardrail (ID + version) to a Converse/InvokeModel call, or call **`ApplyGuardrail`** standalone to evaluate content without invoking any model — useful for pre-screening and for testing guardrail changes without inference cost.

For RAG and chat, tag input sections to **selectively evaluate only the end-user's turn**, excluding system instructions, retrieved context, and history. This is **SDK-only** — not available in the console or Playground — and it is the fix for guardrails firing on your own retrieved documents.

Guardrails have a **working draft** you iterate on, then **version**; use the versioned guardrail in production.

## VPC and PrivateLink

> Source: https://docs.aws.amazon.com/bedrock/latest/userguide/usingVPC.html

Use an **interface VPC endpoint via AWS PrivateLink** to keep Bedrock traffic off the public internet. VPC Flow Logs monitor traffic on job containers.

Features with explicit VPC-scoped support: model customization jobs (optional VPC protection), batch inference jobs, and Knowledge Bases (via an interface endpoint into the underlying Amazon OpenSearch Serverless collection).

Setup pattern: use or create a VPC → keep default DNS settings on the endpoint route table so standard S3 URLs (`http://s3-<region>.amazonaws.com/<bucket>`) still resolve → create the Bedrock interface endpoint → restrict S3 data access through the VPC where applicable.

Deeper VPC design, PrivateLink topology, and org-wide networking belong to the `cloud-platforms` plugin.

## Claude on Bedrock

> Source: https://platform.claude.com/docs/en/api/claude-on-amazon-bedrock

Anthropic documents **three** distinct ways Claude reaches AWS:

1. **Legacy Bedrock integration** — `InvokeModel`/`Converse` with ARN-versioned model IDs (`anthropic.claude-opus-4-6-v1`) and AWS event-stream encoding.
2. **Messages-API Bedrock endpoint** ("Claude in Amazon Bedrock") — the native Messages API at `/anthropic/v1/messages` with SSE streaming. The newest models (Fable 5, Opus 5, Sonnet 5, Opus 4.8/4.7) use this; they are reachable through `InvokeModel` on `bedrock-runtime` served by the same infrastructure, but have **no ARN-versioned model ID**.
3. **Claude Platform on AWS** — Anthropic-operated, billed via AWS Marketplace in Claude Consumption Units, typically gets new features same-day.

### Setup

1. AWS CLI ≥ 2.13.23, configured, verified with `aws sts get-caller-identity`.
2. SDK: `pip install -U "anthropic[bedrock]"`, `npm install @anthropic-ai/bedrock-sdk`, `dotnet add package Anthropic.Bedrock`, `go get github.com/anthropics/anthropic-sdk-go/bedrock`, Maven/Gradle `com.anthropic:anthropic-java-bedrock` — or `boto3 >= 1.28.59` directly.
3. Request Anthropic model access in Console → Bedrock → Model access, subject to regional availability.

### Model IDs

Newer Claude models are offered **only via cross-region inference profiles**. Calling a base model ID fails with:

```
Invocation of model ID anthropic.claude-sonnet-4-5-20250929-v1:0 with on-demand throughput isn't supported.
Retry your request with the ID or ARN of an inference profile that contains this model.
```

Profile ID = geography prefix + base model ID (`us.anthropic.claude-sonnet-4-5-20250929-v1:0`), or the full ARN `arn:aws:bedrock:{region}:{account-id}:inference-profile/{inference-profile-id}`.

| Model | Base Bedrock model ID | global | us | eu | jp | apac |
|---|---|---|---|---|---|---|
| Claude Opus 4.6 | `anthropic.claude-opus-4-6-v1` | Yes | Yes | Yes | Yes | Yes |
| Claude Sonnet 4.6 | `anthropic.claude-sonnet-4-6` | Yes | Yes | Yes | Yes | No |
| Claude Sonnet 4.5 | `anthropic.claude-sonnet-4-5-20250929-v1:0` | Yes | Yes | Yes | Yes | No |
| Claude Sonnet 4 (deprecated) | `anthropic.claude-sonnet-4-20250514-v1:0` | Yes | Yes | Yes | No | Yes |
| Claude Sonnet 3.7 (retired) | `anthropic.claude-3-7-sonnet-20250219-v1:0` | No | No | No | No | No |
| Claude Opus 4.5 | `anthropic.claude-opus-4-5-20251101-v1:0` | Yes | Yes | Yes | No | No |
| Claude Opus 4.1 (deprecated) | `anthropic.claude-opus-4-1-20250805-v1:0` | No | Yes | No | No | No |
| Claude Opus 4 (retired) | `anthropic.claude-opus-4-20250514-v1:0` | No | No | No | No | No |
| Claude Haiku 4.5 | `anthropic.claude-haiku-4-5-20251001-v1:0` | Yes | Yes | Yes | No | No |
| Claude Haiku 3.5 (deprecated) | `anthropic.claude-3-5-haiku-20241022-v1:0` | No | Yes | No | No | No |

Claude Fable 5, Opus 5, Sonnet 5, Opus 4.8, and Opus 4.7 have **no ARN-versioned IDs**; call them via `InvokeModel` on `bedrock-runtime` using the Messages-API request shape.

Enumerate live: `aws bedrock list-foundation-models --region=us-west-2 --by-provider anthropic --query "modelSummaries[*].modelId"`, or `bedrock_client.list_foundation_models(byProvider="anthropic")`.

**Model lifecycle dates on Bedrock are set by AWS**, independently of Anthropic's own deprecation schedule. Never plan a Bedrock migration off the first-party deprecation calendar.

### Making requests

```python
from anthropic import AnthropicBedrock

client = AnthropicBedrock(
    aws_access_key="<access key>",
    aws_secret_key="<secret key>",
    aws_session_token="<session_token>",   # optional, temp creds
    aws_region="us-west-2",                # SDK does NOT read ~/.aws/config for region
)
message = client.messages.create(
    model="global.anthropic.claude-opus-4-6-v1",
    max_tokens=256,
    messages=[{"role": "user", "content": "Hello, world"}],
)
```

`AnthropicBedrock` **does not read the region from `~/.aws/config`** — pass `aws_region` explicitly or requests go to the wrong place.

Raw boto3:

```python
import boto3, json
bedrock = boto3.client(service_name="bedrock-runtime")
body = json.dumps({
    "max_tokens": 256,
    "messages": [{"role": "user", "content": "Hello, world"}],
    "anthropic_version": "bedrock-2023-05-31",
})
response = bedrock.invoke_model(body=body, modelId="global.anthropic.claude-opus-4-6-v1")
```

cURL against `InvokeModel` requires **SigV4 signing**, not a bearer token. The SDKs handle it.

**Bearer-token alternative** for teams that cannot manage IAM credentials: set `AWS_BEARER_TOKEN_BEDROCK`, or pass `api_key=` to `AnthropicBedrock`.

### Global vs regional endpoints

From Claude Sonnet 4.5 onward:

- **Global endpoints** (`global.` prefix) — dynamic routing for max availability, **no pricing premium**, recommended default.
- **Regional endpoints (CRIS)** (`us.`, `eu.`, `jp.`, `apac.`) — guaranteed geography routing for data residency, **10% pricing premium**.

Switching is a prefix swap: `global.anthropic.claude-opus-4-6-v1` → `us.anthropic.claude-opus-4-6-v1`. The premium structure applies only to Sonnet 4.5 and later; earlier models keep prior pricing.

### Feature parity vs the first-party API

**Supported on Bedrock**: Messages API, prompt caching, extended thinking, tool use (Bash, Computer use, Memory, Text editor), citations, structured outputs.

**Not supported on Bedrock** as of 2026-08-05:

- Input sources: URL sources for images/documents, Files API
- Server-side tools: code execution, web search, web fetch, advisor
- Agent infrastructure: Agent Skills, MCP connector, programmatic tool calling
- Endpoints: Message Batches, Models, Admin, Compliance, Usage and Cost
- Claude Managed Agents
- Server-side fallback (`fallbacks` parameter) — implement client-side fallback instead

**Context window**: Fable 5, Opus 5, Opus 4.8/4.7/4.6, Sonnet 5, and Sonnet 4.6 get the full **1M-token window** on Bedrock. Sonnet 4.5 and Sonnet 4 cap at 200k. **Request payload caps at 20 MB** regardless of token limit.

**Activity logging**: Bedrock invocation logging can capture prompts and completions; Anthropic recommends at least a 30-day rolling log for misuse investigation. Enabling it does not give AWS or Anthropic access to your content.

## Sources

- https://docs.aws.amazon.com/bedrock/latest/userguide/conversation-inference.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/inference.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/security-iam.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/security_iam_id-based-policy-examples.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/cross-region-inference.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/prov-throughput.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html
- https://docs.aws.amazon.com/bedrock/latest/userguide/usingVPC.html
- https://aws.amazon.com/bedrock/pricing/
- https://platform.claude.com/docs/en/api/claude-on-amazon-bedrock

Fetched: 2026-08-05
