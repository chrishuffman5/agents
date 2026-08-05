# OWASP Top 10 for LLM Applications — 2025 edition

Read when the request cites an `LLM0x` identifier, asks for coverage of "the OWASP LLM list," or needs a per-risk mitigation write-up for an application security review.

## Edition and versioning

> Source: https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/

- Published **2024-11-17** as the "2025" edition. The OWASP GenAI Security Project labels the list by the year it applies to, not the year it shipped — expect confusion in audit documents and state the publication date explicitly.
- Started in 2023 as a community-driven effort. The 2025 edition reflects real-world incidents, emerging attack techniques, and the growth of **agentic AI**.
- Relative to the prior (2023/24) list: two new categories added, several entries substantially reworked, risks reordered on community feedback, overlapping entries consolidated.
- Headline reordering: **Prompt Injection holds #1 for the second consecutive edition**; **Sensitive Information Disclosure moved from 6th to 2nd**.
- Full PDF: `https://owasp.org/www-project-top-10-for-large-language-model-applications/assets/PDF/OWASP-Top-10-for-LLMs-v2025.pdf` (large; prefer the HTML resource pages for quick reference).

## The ten categories

> Source: https://genai.owasp.org/llm-top-10/

### LLM01:2025 — Prompt Injection

User prompts, or third-party content the LLM ingests, alter the model's intended behavior. Covers **direct** injection (the end user is the attacker) and **indirect** injection (adversarial instructions embedded in web pages, documents, emails, or tool output processed on a trusted user's behalf).

**Mitigation:** input validation and sanitization; treat all externally-sourced content as untrusted data rather than instructions; least privilege on any tool or action the model can trigger as a result of processing that content.

### LLM02:2025 — Sensitive Information Disclosure

Affects both the model and its application context: training-data leakage, PII in outputs, secrets and API keys surfaced in completions, proprietary system context exposed to users.

**Mitigation:** control data access at the source; encrypt; establish data handling and classification protocols; scrub sensitive fields before they reach the context window.

### LLM03:2025 — Supply Chain

Vulnerabilities across pretrained models, fine-tuning data, plugins/extensions, and third-party datasets. Risk can be introduced at any point from training through deployment.

**Mitigation:** vet third-party components (models, datasets, LoRA adapters, plugins); monitor dependencies for tampering; maintain secure procurement and provenance processes such as signed model artifacts and ML-equivalent SBOMs.

### LLM04:2025 — Data and Model Poisoning

Pre-training, fine-tuning, or embedding data is deliberately manipulated to introduce vulnerabilities, backdoors, or biases that compromise security, effectiveness, or ethical behavior.

**Mitigation:** validate training/fine-tuning data provenance; integrity checks (checksums, anomaly detection on data distributions); isolate and version training pipelines.

### LLM05:2025 — Improper Output Handling

Insufficient validation, sanitization, and post-processing of model output **before it is passed downstream** — output fed unsanitized into a shell, SQL query, browser (XSS), or another system.

**Mitigation:** validate and encode output before use; treat model output as untrusted input to whatever consumes it, with the same rigor applied to user input reaching a database or shell.

### LLM06:2025 — Excessive Agency

An LLM-based system granted excessive functionality, permissions, or autonomy. The model can be induced — by poisoning, injection, or plain error — to take consequential actions (delete data, send email, spend money) beyond what the task requires.

**Mitigation:** restrict system permissions to the minimum required; require human-in-the-loop approval for high-impact actions; constrain the tool/function set per task rather than granting broad standing access.

### LLM07:2025 — System Prompt Leakage

Unauthorized disclosure of system-level instructions to end users. Attackers use leaked prompts to reverse-engineer guardrails, discover hidden functionality, and craft better jailbreaks.

**Mitigation:** do not rely on the system prompt as a secret or a security boundary; treat any sensitive logic embedded there as effectively public; monitor access logs; limit how much operational detail the system prompt carries.

### LLM08:2025 — Vector and Embedding Weaknesses

RAG-specific vulnerabilities: embedding inversion attacks, cross-tenant data leakage in shared vector stores, poisoning of the vector index to bias retrieval toward attacker-controlled content.

**Mitigation:** secure vector storage with tenant isolation and access controls on the vector DB; validate ingested documents before embedding; monitor for anomalous retrieval patterns.

### LLM09:2025 — Misinformation

LLM-generated misinformation — hallucination and confidently wrong output — is a core vulnerability wherever applications rely on output accuracy and users treat it as authoritative.

**Mitigation:** fact-checking mechanisms; ground and cite outputs against verifiable sources; require source verification in the UX for high-stakes claims.

### LLM10:2025 — Unbounded Consumption

An LLM operating without resource constraints, enabling denial-of-wallet (excessive API cost), denial-of-service, and model-extraction attacks via unbounded high-volume querying.

**Mitigation:** rate limiting, token quotas, and resource monitoring/alerting per user and per API key; cap max output tokens and concurrent requests.

## Mapping notes

> Source: https://genai.owasp.org/llm-top-10/

- LLM01 is the entry point for most agent- and MCP-specific attacks. The lethal trifecta, tool poisoning, and confused-deputy patterns are specializations of **LLM01 combined with LLM06**.
- LLM08 is the RAG-specific category most relevant to retrieval-augmented agent architectures.
- When writing a NIST AI RMF-aligned report, OWASP categories are the engineering evidence under the RMF **Map** and **Measure** functions; see `../governance-frameworks.md`.

## Sources

- https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/
- https://genai.owasp.org/llm-top-10/
- https://owasp.org/www-project-top-10-for-large-language-model-applications/assets/PDF/OWASP-Top-10-for-LLMs-v2025.pdf

Fetched: 2026-08-05
