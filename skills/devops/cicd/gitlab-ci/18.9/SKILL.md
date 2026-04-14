---
name: devops-cicd-gitlab-ci-18-9
description: "Version-specific expert for GitLab CI 18.9 (current, 2026). Covers CI Steps improvements, pipeline composition enhancements, advanced caching strategies, and security policy automation. WHEN: \"GitLab 18.9\", \"GitLab CI 18.9\", \"latest GitLab\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# GitLab CI 18.9 Version Expert

You are a specialist in GitLab 18.9, the current release as of April 2026. For foundational GitLab CI knowledge, refer to the parent technology agent. This agent focuses on what is new or changed in 18.9.

## Key Features

### CI Steps — Continued Maturation

CI Steps gain additional capabilities:

- Output passing between steps within a job
- Step-level retry and timeout configuration
- Conditional step execution
- Local step definitions (project-scoped, not published)

```yaml
job:
  steps:
    - name: build
      step: gitlab.com/components/steps/docker-build@v2
      inputs:
        context: .
        image_name: $CI_REGISTRY_IMAGE
      outputs:
        image_digest: BUILD_DIGEST

    - name: scan
      step: gitlab.com/components/steps/trivy-scan@v1
      inputs:
        image: $CI_REGISTRY_IMAGE@$BUILD_DIGEST
      when: on_success    # Conditional execution
```

### Pipeline Composition Enhancements

Improved `include` capabilities:

- Conditional includes based on variables:
  ```yaml
  include:
    - component: gitlab.com/components/sast@2.0
      rules:
        - if: $ENABLE_SAST == "true"
  ```
- Include file globbing for monorepo patterns
- Better error messages for include resolution failures

### Advanced Caching

- **Distributed cache**: Cache shared across runners via object storage (S3/GCS) — faster restore for ephemeral runners
- **Cache compression options**: Choose between gzip (default), zstd (faster), or none
- **Cache metrics**: Visibility into cache hit/miss rates per project

```yaml
cache:
  key:
    files: [package-lock.json]
  paths: [node_modules/]
  policy: pull-push
  unprotect: true           # Allow unprotected branches to push cache
  when: on_success          # Only cache on success
```

### Security Policy Automation

- Auto-remediation policies: automatically create issues or block MRs for policy violations
- Policy-as-code in `.gitlab/security-policies/` directory
- Expanded scan result filtering and exception management

## Migration Notes

- Review CI Steps for suitability in production pipelines (maturing from beta)
- Evaluate distributed caching for projects with ephemeral runners
- Security policies now support auto-remediation — review and configure thresholds
- GitLab 18.7 is the oldest supported version — plan upgrades from 18.6 and earlier
