# Security and License Verification

Use this reference when changing a default, evaluating a challenger, or making a high-risk recommendation. It is a source registry and verification procedure, not a set of completed evidence records or a substitute for a threat model. Source registry last reviewed: 2026-08-04.

## Evidence Record

For every candidate, record:

```yaml
technology: <name and edition>
version_or_channel: <supported release/channel>
verified_at: <YYYY-MM-DD>
deployment_model: <self-hosted/managed and topology>
threat_model: <exposure, data, tenancy, untrusted inputs/code>
license:
  spdx: <identifier>
  production_components_checked: <repositories/artifacts>
  open_core_boundary: <none or gated features/code paths>
security:
  advisory_source: <official URL>
  support_window: <official URL and dates>
  secure_configuration: <official URL>
supply_chain:
  artifact_source: <official registry/release URL>
  signatures_or_provenance: <evidence or gap>
  sbom: <evidence or gap>
operations:
  patch_owner: <role/team>
  backup_restore_evidence: <test/date>
  incident_owner: <role/team>
decision: <pass/fail/exception and rationale>
review_due: <YYYY-MM-DD or triggering event>
```

Use the exact edition and artifacts that will run in production. A repository license does not automatically cover a vendor image, plugin, chart, hosted service, or enterprise directory.

## Verification Procedure

1. Identify every production artifact, transitive image, plugin, and required operational feature.
2. Verify the license from the upstream repository and the [OSI license list](https://opensource.org/licenses). Record mixed-license and open-core directories separately.
3. Verify the supported release and security-advisory channel. Reject end-of-life branches and undocumented binaries.
4. Review upstream hardening guidance against the proposed topology. Product capability does not prove deployment safety.
5. Check release provenance, signatures, checksums, SBOM availability, maintainer controls, and repository posture. Treat missing evidence as a risk, not as success.
6. Confirm the team can patch, rotate, restore, investigate, and upgrade within its objectives. Rehearse the restore/rollback path.
7. For an exception, state why the safer outcome requires it, who approved it, what data/identity it receives, and how to exit.

## Primary Security Sources

### Cross-cutting practice

- [NIST Secure Software Development Framework (SP 800-218)](https://csrc.nist.gov/pubs/sp/800/218/final)
- [NIST Contingency Planning Guide (SP 800-34 Rev. 1)](https://csrc.nist.gov/pubs/sp/800/34/r1/upd1/final)
- [NIST Incident Response Recommendations (SP 800-61 Rev. 3)](https://csrc.nist.gov/pubs/sp/800/61/r3/final)
- [NIST Key Management Recommendations (SP 800-57 Part 1 Rev. 5)](https://csrc.nist.gov/pubs/sp/800/57/pt1/r5/final)
- [SLSA supply-chain framework](https://slsa.dev/)
- [OpenSSF Scorecard](https://scorecard.dev/)
- [CycloneDX specification](https://cyclonedx.org/specification/overview/)
- [Sigstore Cosign documentation](https://docs.sigstore.dev/cosign/)

### Application and identity

- [Django security documentation](https://docs.djangoproject.com/en/5.2/topics/security/)
- [Django supported versions](https://www.djangoproject.com/download/#supported-versions)
- [FastAPI security documentation](https://fastapi.tiangolo.com/tutorial/security/)
- [Next.js security advisories](https://nextjs.org/blog/security)
- [Keycloak security documentation](https://www.keycloak.org/security)
- [OWASP Application Security Verification Standard](https://owasp.org/www-project-application-security-verification-standard/)

### Runtime, delivery, and observability

- [Podman rootless mode](https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode)
- [Kubernetes security checklist](https://kubernetes.io/docs/concepts/security/security-checklist/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [GitLab Runner security](https://docs.gitlab.com/runner/security/)
- [GitLab merge-request approval tier boundaries](https://docs.gitlab.com/user/project/merge_requests/approvals/)
- [GitLab audit-event tier boundaries](https://docs.gitlab.com/user/compliance/audit_events/)
- [Forgejo branch and tag protection](https://forgejo.org/docs/latest/user/protection/)
- [Woodpecker project security settings](https://woodpecker-ci.org/docs/usage/project-settings)
- [Woodpecker agent transport and token settings](https://woodpecker-ci.org/docs/administration/configuration/agent)
- [Argo CD security considerations](https://argo-cd.readthedocs.io/en/stable/operator-manual/security/)
- [Prometheus security model](https://prometheus.io/docs/operating/security/)
- [Grafana security configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/)
- [OpenTelemetry security guidance](https://opentelemetry.io/docs/security/)

### Data and infrastructure

- [PostgreSQL security information](https://www.postgresql.org/support/security/)
- [Apache Airflow security model](https://airflow.apache.org/docs/apache-airflow/stable/security/security_model.html)
- [Apache Superset production security](https://superset.apache.org/docs/security/securing_superset/)
- [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https)
- [Ceph hardware recommendations](https://docs.ceph.com/en/latest/start/hardware-recommendations/)
- [Ceph security documentation](https://docs.ceph.com/en/latest/security/)
- [Ubuntu release and security-maintenance lifecycle](https://ubuntu.com/about/release-cycle)

## Primary Project and License Sources

- [OpenBao repository and MPL-2.0 license](https://github.com/openbao/openbao)
- [OpenBao security model](https://openbao.org/docs/internals/security/)
- [Infisical repository and license boundary](https://github.com/Infisical/infisical)
- [Infisical self-hosted audit-log licensing](https://infisical.com/docs/documentation/platform/audit-logs)
- [GitLab Community Edition licensing](https://docs.gitlab.com/development/licensing/)
- [Forgejo GPLv3+ licensing](https://forgejo.org/imprint/)
- [Woodpecker Apache-2.0 license](https://github.com/woodpecker-ci/woodpecker/blob/main/LICENSE)
- [Linkerd licensing](https://github.com/linkerd/linkerd2/blob/main/LICENSE)
- [Linkerd release channels](https://linkerd.io/releases/)
- [OpenTofu repository and license](https://github.com/opentofu/opentofu)
- [HashiCorp licensing FAQ](https://www.hashicorp.com/en/bsl)
- [GNU Affero General Public License text](https://www.gnu.org/licenses/agpl-3.0.en.html)
- [OSI AGPL-3.0 entry](https://opensource.org/license/agpl-v3)
- [Apache CloudStack](https://cloudstack.apache.org/)
- [OpenStack](https://www.openstack.org/)

Do not copy a volatile claim from this list without opening the source and recording a fresh `verified_at` date. If upstream documentation conflicts with this skill, upstream current facts win and the skill must be updated.

## Supply-Chain Tool Sources

- [Renovate](https://docs.renovatebot.com/)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [Trivy](https://trivy.dev/)
- [Syft](https://github.com/anchore/syft)
- [Dependency-Track](https://dependencytrack.org/)
- [Kyverno](https://kyverno.io/)
- [Semgrep Community Edition](https://semgrep.dev/docs/semgrep-code/ce-vs-pro/)
- [OWASP ZAP](https://www.zaproxy.org/)

Prefer primary project documentation, repositories, security advisories, and license text. Use third-party comparisons only to discover questions, never as the final evidence for a license or security-support claim.
