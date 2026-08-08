# Cursor enterprise administration, privacy, and security posture

Read this when answering an admin or security-review question: SSO/SCIM setup, RBAC, org-wide controls, Privacy Mode and Zero Data Retention, data residency, certifications, or what Cursor does with customer code.

## Identity and access management

> Source: https://cursor.com/docs/enterprise/identity-and-access-management.md

**SSO/SAML:** Cursor supports "SAML 2.0 with providers like Okta, Azure AD, Google Workspace, and OneLogin." Organizations can **require SSO for all team members and disable password-based login**. Multi-team orgs can use shared org-level SSO via Organizations.

**SCIM provisioning:** SCIM 2.0, available on **Enterprise plans with SSO enabled**. It automates access provisioning when employees join designated IdP groups, immediate access revocation on IdP departure, and automatic sync of group-membership changes. Multi-team orgs can sync directory groups at the org level and reuse them across teams via Organization Groups.

**RBAC:** three roles — **Members, Admins, and Unpaid Admins**. The Unpaid Admin role exists so an administrator who does not use Cursor need not consume a paid seat.

Note: the pricing page markets "SAML/OIDC SSO", but the IAM documentation page names only SAML 2.0. **Standalone OIDC support is unconfirmed** — do not promise it.

## Admin dashboard controls

> Source: https://cursor.com/enterprise

- Role-based permissions
- **Model and MCP server whitelisting/blocklisting** — the control point for restricting which models and which MCP servers a team may use
- Repository access controls
- Global agent execution settings
- Analytics dashboards: adoption metrics, usage by team and individual, AI-assisted code statistics, productivity insights, with data export via API

**Hard deployment limitation:** Cursor runs on **AWS infrastructure only — on-premises or VPC deployment is not currently available** (per cursor.com/enterprise, 2026-08-05). State this plainly to any organization with a self-hosting or in-VPC requirement; there is no documented workaround.

## Privacy Mode and data governance

> Source: https://cursor.com/docs/enterprise/privacy-and-data-governance.md

**Enabling and enforcing:** admins enable Privacy Mode for a team via the team dashboard (Settings) and can optionally **enforce** it so members cannot disable it.

Pair enforcement with the MDM **"Allowed Team IDs"** policy, which prevents users from logging into personal accounts on corporate devices. Without it, a user can sidestep team Privacy Mode by signing into a personal account on the same machine — this is the gap most often missed in a rollout.

**Zero Data Retention (ZDR):** "Most models run under Cursor's ZDR agreements, so providers don't store inputs or outputs or train on your data." This applies by default to most model providers when Privacy Mode is active.

**Exception — Claude Fable 5:** this model **requires data retention**: "Anthropic stores its inputs and outputs to run automatic and human harm-prevention reviews." It requires **explicit admin approval from the dashboard** before use on Enterprise and Privacy-Mode-enabled teams. Raise this proactively with any org that has committed to ZDR — it is the one documented carve-out.

**Other governance controls:**

- **Data residency** — US-only currently available as of 2026-08-05; EU and APAC are "in development" with no stated timeline. Regional data residency carries a 10% pricing uplift on eligible models (see `models-and-pricing.md`).
- **Customer Managed Encryption Keys (CMEK)**
- Privacy Mode enforcement across teams
- **Model access control** restricting which user groups can access specific models

Data residency, CMEK, and Privacy Mode enforcement setup all route through "contact our team" rather than self-service.

## Security certifications and practices

> Source: https://cursor.com/security

- **SOC 2 Type II** certified; attestation reports available via trust.cursor.com
- Commitment to **at-least-annual penetration testing** by reputable third parties; executive summaries available on request
- Privacy Mode prevents model training on user data via "technical controls and contractual requirements with model providers"; available to all users, admin-enforceable for team/enterprise
- **No infrastructure or subprocessors based in China**
- Published subprocessor list, reviewed annually under vendor risk management
- Access control: principle of least privilege, MFA enforced
- Enterprise features: data encryption and CMEK, security hardening documentation, compliance logging and audit capabilities
- **Network:** the app communicates with Cursor backend domains for API, indexing, update, and marketplace functionality; corporate users can allowlist specific domains for proxy environments
- Vulnerability reports acknowledged within **5 business days** at security-reports@cursor.com; critical incidents communicated directly to affected users

## Privacy policy: code and data handling

> Source: https://cursor.com/privacy

**Training on user code:** "We do not use Inputs or Suggestions to train our models, or permit third parties to use them for training, unless: (1) they are flagged for security review (2) you explicitly report them to us (for example, as Feedback), or (3) you've explicitly agreed to their use for such training purposes." Users manage training preferences in Service settings.

**Data collection:** automatically collects technical data — device details, IP addresses, browser settings, usage patterns, IP-derived location. Explicitly states it does not knowingly collect biometric data, genetic information, health data, or data from users under 18.

**Retention:** personal information is retained "only as long as necessary for Service operation and legitimate business purposes"; deletion procedures apply when data is no longer needed, with timeframes varying by data sensitivity and legal requirements.

**User rights:** residents of certain jurisdictions may request access, deletion, correction, or portability. "We do not 'sell' or 'share' personal data for cross-contextual behavioral advertising," and automated decisions affecting legal rights are prohibited. Privacy questions: hi@cursor.com.

Note the distinction to draw for a security reviewer: the *training* commitment above is a policy covering Cursor's own models, while *Zero Data Retention* is a set of agreements with third-party model providers that applies under Privacy Mode. They are different guarantees with different carve-outs.

## Unverified

The following enterprise documentation pages were discovered via the site index but not fetched. Admin API endpoints and schemas, service-account setup steps, and the audit-log schema remain unconfirmed:

`enterprise/admin-setup-guide.md`, `organizations.md`, `organization-groups.md`, `network-configuration.md`, `endpoint-security.md`, `llm-safety-and-controls.md`, `model-and-integration-management.md`, `pooled-usage.md`, `compliance-and-monitoring.md`, `baa.md`, `deployment-patterns.md`, `security-hardening.md`.

Also unconfirmed: standalone OIDC support (only SAML 2.0 is named in the IAM docs), and the EU/APAC data-residency rollout timeline beyond "in development".

## Sources

- https://cursor.com/enterprise
- https://cursor.com/docs/enterprise/identity-and-access-management.md
- https://cursor.com/docs/enterprise/privacy-and-data-governance.md
- https://cursor.com/security
- https://cursor.com/privacy

Fetched: 2026-08-05
