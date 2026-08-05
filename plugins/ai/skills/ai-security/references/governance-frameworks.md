# AI security governance frameworks

Read when the deliverable is compliance-facing: a risk assessment, a control catalogue, or a board-level report. Use OWASP for the engineering checklist and these frameworks for the reporting structure.

## Google SAIF (Secure AI Framework)

> Source: https://saif.google/
> Source: https://saif.google/why-saif

- Introduced **2023**; described as "an externalization of Google's own internal framework for securing its production and use of AI" — a practitioner's guide, not a mirror of Google's implementation. The site states: "The content on this site is intended to provide information and inspiration for industry advancement. It is not a reflection of Google's current technical implementations."
- Rationale: "The novel risks introduced by AI are not yet widely known by technical practitioners, and traditional software security measures may not address the new dimensions that AI introduces."

### Structure — four components

1. **SAIF Map** — shared vocabulary and framework for exploring AI development through a security lens across the lifecycle: data ingestion and processing, training/tuning/evaluation, model frameworks and code, storage and serving infrastructure, application deployment, agent and plugin integrations, model input/output handling.
2. **Risks** — AI development risks and associated controls (15 listed; see below).
3. **Focus on Agents** — dedicated guidance on the "unique security challenges of autonomous systems," including an **Agent Risk Self Assessment** tool where users answer targeted questions to surface relevant controls for their organization.
4. **About SAIF** — Google's AI security experience and context.

### SAIF's 15 risks

> Source: https://saif.google/secure-ai-framework/saif-map

1. Data Poisoning
2. Unauthorized Training Data
3. Model Source Tampering
4. Excessive Data Handling
5. Model Exfiltration
6. Model Deployment Tampering
7. Denial of ML Service
8. Model Reverse Engineering
9. Insecure Integrated Component
10. Prompt Injection
11. Model Evasion
12. Sensitive Data Disclosure
13. Inferred Sensitive Data
14. Insecure Model Output
15. Rogue Actions

The SAIF Map organizes these across the AI lifecycle with a three-part lens per risk: where it can be **Introduced** (systems, processes, and people that could introduce it), where it is **Exposed** (where practitioners, systems, or users encounter it), and where it can be **Mitigated** (where the organization can act to remediate).

**Why this lens is useful:** it assigns each risk to an owning team and lifecycle stage rather than leaving it as a document-level bullet. Use it when a finding needs an accountable owner.

## NIST AI Risk Management Framework (AI RMF)

> Source: https://www.nist.gov/itl/ai-risk-management-framework

- **AI RMF 1.0** released **January 26, 2023**; intended for **voluntary** use; rights-preserving, non-sector-specific, and use-case agnostic — applicable to organizations of any size or sector.
- Goal: help organizations designing, developing, deploying, or using AI systems incorporate **trustworthiness** into design, development, use, and evaluation, and manage AI risk to individuals, organizations, and society.
- Developed through a consensus-driven, open, transparent process with input from **240+ contributing organizations** across private industry, academia, civil society, and government.
- **Four core functions**, presented as a circular/cyclical model: **Govern, Map, Measure, Manage**.
- **Gap:** the fetched pages did not enumerate sub-category detail for each function. Do not invent sub-categories — consult the AI RMF Playbook and Crosswalk resources directly when a control-level mapping is required.
- Supporting resources: **AI RMF Playbook**, **AI RMF Roadmap**, **AI RMF Crosswalk**, various "Perspectives," and the **NIST AI Resource Center (AIRC)**, launched March 30, 2023 at `airc.nist.gov`.
- **April 7, 2026:** NIST released a concept note for an **AI RMF Profile on Trustworthy AI in Critical Infrastructure**, guiding critical-infrastructure operators on risk-management practices for AI-enabled capabilities — the framework is still actively being extended as of 2026-08-05.

### Generative AI Profile (NIST AI 600-1)

> Source: https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-generative-artificial-intelligence

- Published **July 26, 2024** as **NIST.AI.600-1**, a cross-sectoral profile of and companion resource to AI RMF 1.0 specifically for **Generative AI**, developed pursuant to US Executive Order 14110.
- Purpose: help organizations identify risks unique to generative AI and propose risk-management actions aligned with their own goals and priorities.
- Addresses AI lifecycle considerations and integration of trustworthiness into design, development, use, and evaluation for GenAI systems.
- **Gap:** the specific enumerated GenAI risk list and detailed recommended actions inside AI 600-1 were not retrievable from the fetched summary page (the PDF/DOI at `https://doi.org/10.6028/NIST.AI.600-1` was not fetched). Treat the contents as unverified rather than paraphrasing from memory — cite the document and fetch it before enumerating its risks.

## Using the frameworks together

- **NIST AI RMF** is the reporting spine for executives and auditors: Govern/Map/Measure/Manage gives the narrative structure and the accountability model.
- **OWASP LLM Top 10 (2025)** and **OWASP MCP Top 10 (Beta v0.1)** provide the engineering evidence that populates Map and Measure — see `versions/owasp-llm-top10-2025.md` and `versions/owasp-mcp-top10-0.1-beta.md`.
- **SAIF** supplies lifecycle placement and ownership: for each OWASP finding, use the introduced/exposed/mitigated lens to name the team that owns the control.
- Product-level enforcement of SAIF-style controls is available from Google as Model Armor — see `guardrail-apis.md`.

## Sources

- https://saif.google/
- https://saif.google/why-saif
- https://saif.google/secure-ai-framework/saif-map
- https://cloud.google.com/security/products/model-armor
- https://www.nist.gov/itl/ai-risk-management-framework
- https://www.nist.gov/publications/artificial-intelligence-risk-management-framework-generative-artificial-intelligence

Fetched: 2026-08-05
