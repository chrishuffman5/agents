---
name: overview
description: "Cross-platform DevOps strategy: tool selection, CI/CD pipeline architecture, IaC strategy, GitOps design, and deployment strategy across the whole devops plugin. WHEN: \"DevOps maturity\", \"design a CI/CD pipeline\", \"which IaC tool\", \"push vs pull deployment\", \"deployment strategy\", \"Terraform vs Ansible\", \"ArgoCD vs Flux\", \"continuous integration\", \"continuous delivery\", \"infrastructure automation strategy\". Do NOT use for single-technology implementation, syntax, or debugging questions — read that technology's skill directly (e.g. `terraform`, `github-actions`, `ansible`)."
license: MIT
---

# DevOps / CI-CD / IaC Domain Overview

This skill covers cross-platform DevOps, CI/CD, Infrastructure as Code, and GitOps expertise: deployment pipelines, infrastructure automation, configuration management, and delivery workflows. Read it for strategic and comparison questions; read a technology skill directly for implementation depth.

## When to Use This Skill vs. a Technology Skill

**Use this skill when the question is cross-platform or strategic:**
- "Should I use Terraform or Ansible?"
- "Design a CI/CD pipeline for our organization"
- "Compare GitOps approaches (ArgoCD vs Flux)"
- "What's the right IaC strategy for multi-cloud?"
- "How should we structure our deployment pipeline?"
- "Push-based vs pull-based deployment — which and when?"
- "DevOps maturity assessment"

**Read a technology skill directly when the question is technology-specific:**
- "Terraform state locking issue" --> `terraform` skill
- "OpenTofu state encryption" --> `opentofu` skill
- "Pulumi Output resolution error" --> `pulumi` skill
- "CloudFormation stack rollback" --> `cloudformation` skill
- "Bicep module deployment" --> `bicep` skill
- "Ansible playbook not idempotent" --> `ansible` skill
- "GitHub Actions workflow failing" --> `github-actions` skill
- "GitLab CI runner configuration" --> `gitlab-ci` skill
- "Azure DevOps pipeline YAML" --> `azure-devops` skill
- "Jenkins shared library" --> `jenkins` skill
- "CircleCI orb configuration" --> `circleci` skill
- "ArgoCD application sync" --> `argocd` skill
- "Flux Kustomization not reconciling" --> `flux` skill
- "Branching strategy / PR process / release tagging" --> `github` skill
- "Chef cookbook convergence" --> `chef` skill
- "Puppet manifest compilation" --> `puppet` skill
- "SaltStack state apply" --> `saltstack` skill

## How to Approach Tasks

1. **Classify** the request:
   - **Tool/platform selection** -- Use the comparison tables below
   - **Architecture / pipeline design** -- Load `references/concepts.md` for DevOps principles
   - **Infrastructure as Code** -- Read the `iac` skill
   - **CI/CD pipelines** -- Read the `cicd` skill
   - **GitOps / continuous delivery** -- Read the `gitops` skill
   - **Configuration management** -- Read the `config-mgmt` skill
   - **Version control / repo governance** (branching, PRs, releases/tags) -- Read the `github` skill
   - **Technology-specific** -- Read that technology's skill directly

2. **Gather context** -- Team size, cloud providers, existing tooling, compliance requirements, deployment frequency targets, monorepo vs polyrepo

3. **Analyze** -- Apply DevOps principles (automation, feedback loops, continuous improvement)

4. **Recommend** -- Actionable guidance with trade-offs, not a single answer

## DevOps Principles

1. **Automate everything repeatable** -- Manual steps are error-prone and don't scale. If you do it twice, automate it.
2. **Infrastructure as Code** -- All infrastructure defined in version-controlled, reviewable, testable code.
3. **Continuous Integration** -- Merge to trunk frequently. Every commit triggers automated build and test.
4. **Continuous Delivery** -- Every commit that passes tests is deployable. Deployment is a business decision, not a technical one.
5. **Shift left** -- Find defects earlier (static analysis, unit tests, policy checks in CI, not in production).
6. **Observability** -- If you can't measure it, you can't improve it. Instrument everything.
7. **Immutable infrastructure** -- Replace, don't patch. Build new artifacts, deploy, cut over.
8. **Blast radius reduction** -- Progressive delivery (canary, blue-green, feature flags). Small, frequent releases.

## Technology Comparison

### Infrastructure as Code

| Technology | Model | Language | State | Best For | Trade-offs |
|---|---|---|---|---|---|
| **Terraform** | Declarative | HCL | Remote state file | Multi-cloud, provider ecosystem | State management complexity, HCL learning curve |
| **OpenTofu** | Declarative | HCL | Remote state file | Terraform OSS fork (BSL concerns) | Smaller community, provider lag |
| **Pulumi** | Declarative (imperative syntax) | Python/TS/Go/C# | Managed or self-hosted | Developers who prefer real languages | Vendor lock-in (Pulumi Cloud), debugging complexity |
| **Ansible** | Procedural (mostly) | YAML + Jinja2 | Stateless (agentless) | Config management, orchestration, hybrid | Slow at scale, ordering matters, not truly declarative |
| **CloudFormation** | Declarative | JSON/YAML | AWS-managed stack | AWS-only shops | AWS-only, verbose, slow rollbacks |
| **Bicep/ARM** | Declarative | Bicep DSL / JSON | Azure-managed | Azure-only shops | Azure-only, ARM JSON is painful |

### CI/CD Platforms

| Platform | Model | Hosting | Best For | Trade-offs |
|---|---|---|---|---|
| **GitHub Actions** | YAML workflows | GitHub-hosted or self-hosted runners | GitHub-native, open source, marketplace | Vendor lock-in, runner cost at scale, debugging UX |
| **GitLab CI** | YAML pipelines | GitLab-hosted or self-managed runners | GitLab-native, full DevSecOps platform | Complex YAML, resource-heavy self-hosted |
| **Azure DevOps** | YAML or classic pipelines | Microsoft-hosted or self-hosted agents | Azure/.NET shops, enterprise governance | Dated UI, YAML complexity, migration pain |
| **Jenkins** | Groovy (Declarative/Scripted) | Self-hosted only | Maximum flexibility, plugin ecosystem | Operational burden, security surface, Groovy complexity |
| **CircleCI** | YAML config | Cloud or self-hosted runners | Fast builds, Docker-native, orbs | Pricing, fewer integrations than GitHub Actions |

### GitOps / Continuous Delivery

| Technology | Model | Scope | Best For | Trade-offs |
|---|---|---|---|---|
| **ArgoCD** | Pull-based, app-centric | Kubernetes | Multi-cluster, UI, RBAC, app-of-apps | K8s-only, CRD sprawl, sync wave complexity |
| **Flux** | Pull-based, source-centric | Kubernetes | Lightweight, composable, Helm/Kustomize native | K8s-only, no built-in UI, steeper learning curve |

## Decision Framework

### Step 1: What needs automation?

| Need | Primary Tool Category | Candidates |
|---|---|---|
| Provision infrastructure (VMs, networks, databases) | IaC | Terraform, Pulumi, CloudFormation, Bicep |
| Configure servers (packages, files, services) | Config Management | Ansible, Chef, Puppet, SaltStack |
| Build and test code | CI/CD | GitHub Actions, GitLab CI, Jenkins, Azure DevOps |
| Deploy to Kubernetes | GitOps | ArgoCD, Flux |
| Deploy to VMs/bare metal | CI/CD + Config Mgmt | Jenkins/GHA + Ansible |

### Step 2: Push-based vs Pull-based delivery?

| Model | How It Works | When to Use |
|---|---|---|
| **Push-based** | CI pipeline pushes changes to target (SSH, kubectl apply, API calls) | Non-K8s targets, simple setups, imperative workflows |
| **Pull-based (GitOps)** | Agent in cluster pulls desired state from Git, reconciles | Kubernetes, audit requirements, drift detection |
| **Hybrid** | CI builds + tests; GitOps agent deploys | Most mature setups — CI for build, GitOps for deploy |

### Step 3: What does the team know?

- **Developers comfortable with YAML** --> GitHub Actions, GitLab CI, Flux
- **Developers who prefer real code** --> Pulumi (IaC), Jenkins (Groovy pipelines)
- **Ops teams with shell/Python skills** --> Ansible, Terraform
- **Enterprise with compliance needs** --> Azure DevOps, ArgoCD (RBAC + audit)

## Subcategory Routing

| Request Pattern | Skill |
|---|---|
| **Infrastructure as Code** | |
| Terraform, HCL, providers, state, modules, workspaces | `terraform` |
| OpenTofu, tofu, Terraform fork, state encryption | `opentofu` |
| Pulumi, pulumi up, TypeScript/Python/Go IaC | `pulumi` |
| CloudFormation, CFN, AWS stacks, StackSets, SAM | `cloudformation` |
| Bicep, ARM template, Azure IaC, az deployment | `bicep` |
| Ansible, playbooks, roles, inventory, Jinja2, AWX | `ansible` |
| IaC comparison, Terraform vs Ansible vs Pulumi | `iac` |
| **CI/CD** | |
| GitHub Actions, workflows, runners, marketplace actions | `github-actions` |
| GitLab CI, .gitlab-ci.yml, runners, stages, artifacts | `gitlab-ci` |
| Azure DevOps, Azure Pipelines, YAML pipelines, boards | `azure-devops` |
| Jenkins, Jenkinsfile, plugins, shared libraries, agents | `jenkins` |
| CircleCI, config.yml, orbs, test splitting, contexts | `circleci` |
| CI/CD comparison, pipeline design, which platform | `cicd` |
| **GitOps** | |
| ArgoCD, Application, ApplicationSet, sync, app-of-apps | `argocd` |
| Flux, GitRepository, Kustomization, HelmRelease, source | `flux` |
| GitOps comparison, ArgoCD vs Flux, pull-based delivery | `gitops` |
| **Version Control / Repo Management** | |
| Branching strategy, trunk-based, GitHub Flow, GitFlow, release branches | `github` |
| Pull request process, code review, CODEOWNERS, branch protection, rulesets, merge strategy | `github` |
| Release management, semantic versioning, conventional commits, git tags, GitHub Releases, changelog | `github` |
| **Configuration Management** | |
| Chef, cookbook, recipe, knife, InSpec, Habitat | `chef` |
| Puppet, manifest, Facter, Hiera, PuppetDB, Bolt | `puppet` |
| SaltStack, Salt, minion, grain, pillar, state file | `saltstack` |
| Config management comparison, Chef vs Puppet vs Salt | `config-mgmt` |
| GitOps comparison, ArgoCD vs Flux, pull-based delivery | `gitops` |

## Anti-Patterns

1. **"Automate last mile manually"** -- If CI builds and tests automatically but deployment is a manual SSH, you have 90% of the risk in the 10% you didn't automate.
2. **"IaC without state management"** -- Terraform without remote state + locking = guaranteed state corruption in teams.
3. **"Jenkins for everything"** -- Jenkins can do anything but should do less. Its flexibility is also its vulnerability surface.
4. **"GitOps without CI"** -- GitOps handles delivery, not integration. You still need CI for build, test, and image creation.
5. **"One pipeline for all environments"** -- Dev, staging, and production have different requirements. Promotion gates, not identical pipelines.
6. **"Secrets in Git"** -- Even encrypted secrets in Git are risky. Use external secret managers (Vault, AWS Secrets Manager, Azure Key Vault) with runtime injection.

## Reference Files

- `references/concepts.md` -- DevOps fundamentals (CI/CD theory, deployment strategies, pipeline design, environment management, secret management patterns). Read for architecture and comparison questions.
