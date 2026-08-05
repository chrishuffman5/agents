# Microsoft Foundry (Azure AI Foundry)

Read when you are choosing a Foundry deployment type or SKU, debugging Foundry auth and RBAC, deploying a partner model such as Claude, or reconciling Azure Marketplace / CCU billing.

Snapshot of Microsoft and Anthropic docs on 2026-08-05. SKU names, region availability, and PTU economics move — re-verify at the URLs below.

## Product naming

> Source: https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types

Microsoft has rebranded **Azure AI Foundry** to **Microsoft Foundry**. The `ai-foundry` URL path still resolves and redirects into `foundry`/`foundry-classic` doc trees. **Both a "Foundry (classic) portal" and a "Foundry (new) portal" coexist**, and deployment steps differ slightly between them — check which portal a doc or screenshot is describing before following it.

## Model catalog structure

> Source: https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/model-catalog-overview

Over **10,000 models**, ~50 new per month, in two commercially distinct categories:

| | Foundry Models sold by Azure | Foundry Models from partners and community |
|---|---|---|
| Who hosts and sells | Microsoft, under Microsoft Product Terms | Third parties; **billed through Azure Marketplace** under Commercial Marketplace Terms of Use |
| Support | Microsoft, enterprise SLAs | The respective provider, varying SLA levels |
| Responsible-AI review | Microsoft's internal review | Provider's own |
| Billing meter | Azure meters, "First Party Consumption Services" | Azure Marketplace |
| Notable | Some offer **fungible provisioned throughput** — quota/reservations usable across any model in the fungible group | The majority of the catalog: Anthropic's Claude family, Hugging Face hub models, research labs |

Catalog filters: Collections (provider), Region, Deployment options, Deployment SKU, Lifecycle (Preview/GA/Deprecated), Industry, Supported features, Inference tasks.

**Instant access (preview)**: for supported models, call by name and run inference with **no deployment step at all**.

Microsoft's own selection framework: deep Azure integration + guaranteed SLA + Microsoft support → models sold by Azure. Specialized, niche, or innovation-led use cases → partner and community models, accepting provider-managed support in exchange for faster access to frontier capabilities.

## Managed compute vs serverless

> Source: https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/model-catalog-overview

| | Managed compute | Serverless deployment |
|---|---|---|
| Billing | VM core-hours | Per input/output token |
| Hosting | Model weights on dedicated VMs you provision, via Azure Machine Learning registries | Microsoft-hosted; you just call the API |
| Auth | Keys or Microsoft Entra ID | Keys or Microsoft Entra ID |
| Content safety | Bring your own, via Azure AI Content Safety APIs | Integrated Content Safety filters, **billed separately**, on by default, disableable per deployment |
| Network isolation | Managed network config on the Foundry hub | Follows the Foundry resource's public-network-access (PNA) flag |

**The model provider decides which options are available for their model** — you do not get to choose managed compute for a model whose provider only ships serverless.

## Deployment types (serverless)

> Source: https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types

Two top-level categories — **Standard** (pay-per-token) and **Provisioned** (reserved PTU) — each split by data-processing scope: Global, Data Zone, or single Region.

| Deployment type | SKU code | Data processing | Billing | Best for |
|---|---|---|---|---|
| Instant (preview) | N/A (no deployment) | Any Azure region | Pay-per-token, global quota | Prototyping, trying new models |
| Global Standard | `GlobalStandard` | Any Azure region | Pay-per-token | General workloads, highest quota |
| Global Provisioned | `GlobalProvisionedManaged` | Any Azure region | Reserved PTU | Predictable high throughput, no residency constraint |
| Global Batch | `GlobalBatch` | Any Azure region | **50% discount**, 24-hr target turnaround | Large async jobs |
| Data Zone Standard | `DataZoneStandard` | Within data zone | Pay-per-token | Zone compliance, higher quota than single-region |
| Data Zone Provisioned | `DataZoneProvisionedManaged` | Within data zone | Reserved PTU | Zone compliance + predictable throughput |
| Data Zone Batch | `DataZoneBatch` | Within data zone | **50% discount** | Large async jobs with zone compliance |
| Standard | `Standard` | Single region | Pay-per-token | Regional compliance, low-medium volume |
| Regional Provisioned | `ProvisionedManaged` | Single region | Reserved PTU | Regional compliance + guaranteed throughput |
| Developer | `DeveloperTier` | Any Azure region | Pay-per-token, **no SLA** | Fine-tuned model evaluation only; **fixed 24-hour lifetime, auto-deleted** |

### Data residency semantics

- Data **at rest** stays in the designated Azure geography for **all** deployment types. Residency choices are about *inferencing* data.
- **Global** types: inferencing may be processed in **any** Azure region.
- **DataZone** types: processed only within the Microsoft-defined zone — **US** (anywhere in US), **EU** (within the Azure EU Data Boundary; as of May 2026 France, Germany, Italy, Netherlands, Norway, Poland, Spain, Sweden, Switzerland, possibly more since), **APAC** (Australia, Japan, Korea, Singapore, India).
- **Standard / Regional**: processed strictly in the deployment region.

### Choosing

- **By residency**: no restriction → Global Standard/Provisioned. EU/US/APAC zone → Data Zone Standard/Provisioned. Single region only → Standard / Regional Provisioned.
- **By workload**: prototyping → Instant. Bursty or variable → Standard / Global Standard. Consistent high volume → Provisioned. Large non-time-sensitive → Global/DataZone Batch (50%). Fine-tuned model eval → Developer.
- **By latency**: need low latency *variance* at scale → Provisioned. Variance acceptable → Standard.

Global deployments get the **highest default quota, broadest model availability, and new models/features first**, at the cost of more latency variance under sustained high volume. Standard-family SKUs carry **no SLA guarantee on latency variance**; Provisioned guarantees throughput and lower variance; Developer has no SLA at all.

### PTU mechanics

Provisioned throughput is purchased in **Provisioned Throughput Units (PTUs)** — a normalized throughput representation. **Each model-version pair requires a different number of PTUs and yields different throughput per PTU**, and minimum PTU requirements vary by model. Sizing does not transfer across a model upgrade.

**Unverified — do not quote**: exact minimum PTU counts and current $/PTU. Microsoft's deployment-types page points to a separate "Provisioned throughput concepts" doc that was not fetched. Read it before sizing a reservation.

### Governance

Azure Policy can restrict which deployment types are allowed org-wide — e.g. a `deny`-effect rule on `Microsoft.CognitiveServices/accounts/deployments/sku.name` equal to a disallowed SKU such as `GlobalStandard`. Confirm your target SKU is permitted before designing around it; a policy denial at deploy time is indistinguishable from a quota failure if you are not looking for it.

### Troubleshooting deployment

| Issue | Cause | Fix |
|---|---|---|
| Deployment type unavailable | Model doesn't support that type | Check the model's supported deployment types |
| Quota exceeded | Subscription TPM limit reached | Request an increase, or use a different region |
| Region unavailable | Model not deployed there | Pick from the model's availability list |
| Provisioned capacity unavailable | No PTU capacity in region | Try another region, or use Global Provisioned |

## Claude models in Microsoft Foundry

> Source: https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/how-to/use-foundry-models-claude

### Subscription eligibility — check during procurement

Requires a **paid** Azure subscription with a billing account in a country/region where Anthropic offers the models. **Not supported**:

- Enterprise Accounts in South Korea
- Cloud Solution Provider (CSP) subscriptions
- Subscriptions without an active pay-as-you-go billing method (student, free-trial, startup-credit accounts)
- Sponsored subscriptions relying solely on Azure credits — **a credit card on file gets charged instead of consuming credits**

Also required: a Foundry **project** in a supported region; **Azure Marketplace access** with permission to subscribe to partner/community models; and **Contributor or Owner** RBAC on the resource group to deploy.

### Hosting versions

Claude ships in two hosting versions on Foundry:

- **Version 2: Hosted on Azure** — the default when you use "Deploy → Default settings."
- **Version 1: Hosted on Anthropic infrastructure** — selectable via "Deploy → Custom settings."

All Claude models on both hosting versions support **Global Standard**; some Hosted-on-Azure Claude models also support **Data Zone Standard (US)**. Exact per-model region availability lives on the "Region availability by deployment type" page (not fetched — see gaps).

### Deploying

Foundry (new) portal: Discover → Models → pick a Claude model → **Deploy → Custom settings** → accept Azure Marketplace terms and industry selection → choose hosting version and deployment name → choose **Region scope** (Global or Data Zone) → Deploy. Infrastructure-as-code (Bicep/Terraform) is available via the "Claude on Foundry starter kit."

**The deployment name is what you pass as `model` at inference time**, and it may differ from the catalog model ID.

### Calling the API

Foundry exposes Claude through the **native Anthropic Messages API shape** — not the Azure AI Model Inference API — using Anthropic's SDKs plus a Foundry backend package (`anthropic` Python package with the `AnthropicFoundry` client; `@anthropic-ai/foundry-sdk` for JS).

- **Base URL**: `https://<resource-name>.services.ai.azure.com/anthropic`
- **Messages endpoint**: `https://<resource-name>.services.ai.azure.com/anthropic/v1/messages`
- **Auth**: Microsoft Entra ID (keyless, `DefaultAzureCredential`, scope `https://ai.azure.com/.default`) or a per-deployment API key
- **`model`** = your deployment name

```python
from anthropic import AnthropicFoundry
from azure.identity import DefaultAzureCredential, get_bearer_token_provider

baseURL = "https://<resource-name>.services.ai.azure.com/anthropic"
deploymentName = "claude-sonnet-4-6"
tokenProvider = get_bearer_token_provider(DefaultAzureCredential(), "https://ai.azure.com/.default")
client = AnthropicFoundry(azure_ad_token_provider=tokenProvider, base_url=baseURL)
message = client.messages.create(
    model=deploymentName,
    messages=[{"role": "user", "content": "What are 3 things to visit in Seattle?"}],
    max_tokens=1048, temperature=1,
    thinking={"type": "adaptive"},
    output_config={"effort": "max"},
    stream=False,
)
```

REST with key auth uses **`x-api-key`, not `Authorization: Bearer`**, and requires the `anthropic-version` header:

```bash
curl -X POST https://<resource-name>.services.ai.azure.com/anthropic/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: $AZURE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "messages": [{"role": "user", "content": "What are 3 things to visit in Seattle?"}],
    "max_tokens": 1048, "temperature": 1,
    "model": "claude-sonnet-4-6",
    "thinking": {"type":"adaptive"},
    "output_config": {"effort": "max"},
    "stream": false
  }'
```

**Claude Mythos 5 and Claude Mythos Preview support Microsoft Entra ID authentication only** — API-key auth is unavailable for those two models on Foundry. Plan the identity story before designing around a key.

### Troubleshooting inference

| Error | Cause | Fix |
|---|---|---|
| 401 Unauthorized | Invalid/expired API key, or wrong Entra scope | Verify the key; for Entra confirm scope `https://ai.azure.com/.default` |
| 403 Forbidden | Insufficient RBAC | Contributor/Owner on the resource group; for Entra, the **Cognitive Services User** role |
| 404 Not Found | Wrong endpoint URL or deployment name | Confirm the base URL pattern and that `model` is the deployment name |
| 429 Too Many Requests | Subscription-tier rate limit | Exponential backoff; request a quota increase |
| Subscription eligibility error | Unsupported subscription type/region, or default quota 0 | Confirm active pay-as-you-go billing in a supported billing region |
| Region not available | Deployed to an unsupported region | Deploy to a region on the model's availability list |

## Claude Consumption Unit (CCU) billing

> Source: https://platform.claude.com/docs/en/about-claude/pricing

Claude in Microsoft Foundry bills through **Azure Marketplace** in **Claude Consumption Units**, the same mechanism as Claude Platform on AWS.

| Concept | Detail |
|---|---|
| Billing unit | Claude Consumption Unit (CCU) |
| CCU price | **$0.01 per CCU, fixed** — discounts apply at the token→CCU conversion step, never to the CCU unit price |
| Conversion | Token usage rated in USD at standard Claude API per-model/per-feature rates → negotiated discount applied → converted to CCUs at $0.01/CCU |
| Billing cadence | Hourly metering to Azure Marketplace; monthly invoices |
| Payment model | **Arrears only (postpaid)**; no prepaid credits |
| Cost visibility | Azure Cost Management shows aggregated CCU |

100 CCU = $1.00 of Claude API fees at applicable post-discount rates.

**Inference geography**: deployments on the **US Data Zone Standard** type are equivalent to the first-party API's `inference_geo: "us"` and carry the same **1.1x pricing multiplier** over global/default pricing.

This CCU model is **distinct from** the generic "Foundry Models from partners and community" Azure-Marketplace billing: Anthropic bills its own CCU-metered rate derived from its own per-model USD rates (including negotiated private-offer discounts), rather than Azure setting an independent per-token price for Claude the way it might for other partner models. Do not generalize CCU mechanics to other partner models.

## Known gaps

- Minimum PTU counts and current $/PTU — referenced but not fetched.
- Exact Azure regions where Claude models are deployable, and the Claude "Quotas, rate limits, and regions" page — referenced but not fetched.
- The `model-catalog-overview` page served content from the **Foundry (classic)** doc set; the new-portal equivalent at `.../foundry/concepts/foundry-models-overview` was not fetched separately.

## Sources

- https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/model-catalog-overview
- https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/concepts/deployment-types
- https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/how-to/use-foundry-models-claude
- https://platform.claude.com/docs/en/about-claude/pricing

Fetched: 2026-08-05
