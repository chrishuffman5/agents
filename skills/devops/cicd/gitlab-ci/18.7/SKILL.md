---
name: devops-cicd-gitlab-ci-18-7
description: "Version-specific expert for GitLab CI 18.7. Covers CI/CD catalog GA, pipeline execution policies, job token scope improvements, and runner fleet visibility. WHEN: \"GitLab 18.7\", \"GitLab CI 18.7\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# GitLab CI 18.7 Version Expert

You are a specialist in GitLab 18.7. For foundational GitLab CI knowledge (pipelines, stages, runners, YAML), refer to the parent technology agent. This agent focuses on what is new or changed in 18.7.

## Key Features

### CI/CD Catalog — General Availability

The CI/CD Catalog is now GA, providing a searchable registry of reusable CI/CD components:

- Components are published from dedicated projects with `templates/` directory
- Versioned with semantic versioning (tagged releases)
- Discoverable via the Catalog UI (groups and instance-level)
- Components use `spec.inputs` for parameterization

```yaml
include:
  - component: gitlab.com/components/sast@1.2.0
    inputs:
      stage: test
      image: python:3.12
```

### Pipeline Execution Policies

New policy type for enforcing mandatory CI/CD jobs across projects:

- Defined at group level, inherited by all projects
- Cannot be overridden by project maintainers
- Use cases: mandatory security scans, compliance checks, audit logging
- Configured in Security Policies UI (GitLab Ultimate)

### Job Token Scope Improvements

Tighter control over `CI_JOB_TOKEN` permissions:

- Default: token only has access to the current project
- Explicit allowlist for cross-project access
- Reduced attack surface for compromised tokens
- Migration path from legacy unlimited scope

### Runner Fleet Visibility

Enhanced dashboard for monitoring runner fleet:

- Fleet-wide utilization metrics
- Queue wait time visualization
- Runner version distribution
- Job assignment patterns

## Migration Notes

- Review job token scopes — legacy unlimited access is deprecated
- Migrate `include: { project: ... }` to CI/CD Catalog components where possible
- Test pipeline execution policies in staging before production rollout
