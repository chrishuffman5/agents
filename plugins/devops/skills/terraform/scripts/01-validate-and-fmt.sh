#!/usr/bin/env bash
# Purpose:        Terraform static validation pass - fmt, validate, and provider lock sanity without touching state
# Applies to:     Terraform 1.5+ / OpenTofu (run in the configuration directory)
# Read-only:      yes (init uses -backend=false: no state access, no backend credentials needed)
# Inputs:         run from the Terraform working directory
# Interpretation: fmt -check failures are style drift (CI should gate this). validate errors are structural (bad
#                 references, type errors) - they fail before any plan. A missing/outdated .terraform.lock.hcl means
#                 different machines can resolve different provider builds - commit the lock file. This trio is the
#                 cheapest CI gate; state-touching checks come after (02).
# Next step:      02-drift-preview.sh for state-vs-reality drift (needs backend access)

set -euo pipefail

echo "== Format check"
terraform fmt -check -recursive && echo "fmt: clean"

echo
echo "== Init (no backend) + validate"
terraform init -backend=false -input=false >/dev/null
terraform validate

echo
echo "== Provider lock file"
if [[ -f .terraform.lock.hcl ]]; then
    grep -E '^provider|version' .terraform.lock.hcl | head -20
else
    echo "WARNING: no .terraform.lock.hcl - provider resolution is not pinned; run terraform init and commit the lock file"
fi
