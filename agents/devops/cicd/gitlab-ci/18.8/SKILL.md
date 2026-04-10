---
name: devops-cicd-gitlab-ci-18-8
description: "Version-specific expert for GitLab CI 18.8. Covers CI Steps (beta), pipeline mini-graph improvements, component testing framework, and Kubernetes executor enhancements. WHEN: \"GitLab 18.8\", \"GitLab CI 18.8\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# GitLab CI 18.8 Version Expert

You are a specialist in GitLab 18.8. For foundational GitLab CI knowledge, refer to the parent technology agent. This agent focuses on what is new or changed in 18.8.

## Key Features

### CI Steps — Beta

A new abstraction layer between jobs and scripts. Steps are typed, reusable units of work with defined inputs/outputs:

```yaml
job:
  steps:
    - name: install
      step: gitlab.com/components/steps/npm-install@v1
      inputs:
        node_version: "22"
    - name: test
      step: gitlab.com/components/steps/npm-test@v1
      inputs:
        coverage: true
```

**Step vs Script**: Steps have typed inputs/outputs, versioning, and can be shared across projects. Scripts are raw shell commands.

### Pipeline Mini-Graph Improvements

Enhanced pipeline visualization in merge request widgets:

- Collapsible stage groups
- Clearer status indicators for manual jobs
- Direct links to specific job logs
- Real-time status updates

### Component Testing Framework

New tooling for testing CI/CD components before publishing:

```yaml
# .gitlab/ci/test-component.yml
test_component:
  script:
    - gitlab-ci-component-test validate templates/
    - gitlab-ci-component-test render templates/my-component.yml \
        --inputs stage=test,image=node:22
```

### Kubernetes Executor Enhancements

- Improved pod scheduling with topology spread constraints
- Better resource request auto-tuning based on historical job data
- Native support for ephemeral volumes (faster startup)
- Enhanced cleanup of orphaned pods

## Migration Notes

- CI Steps are beta — evaluate for new projects, don't migrate existing pipelines yet
- Component testing framework is recommended for all CI/CD component authors
- Kubernetes executor users should review new pod scheduling options
