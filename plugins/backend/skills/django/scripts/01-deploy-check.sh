#!/usr/bin/env bash
# Purpose:        Django production-readiness audit - the built-in deploy check, migration drift, and dependency vulns
# Applies to:     Django 4.2/5.x (run in the project venv, from the manage.py directory)
# Read-only:      yes (check and --check do not modify the database or code)
# Inputs:         __SETTINGS_MODULE__ if not the default (export DJANGO_SETTINGS_MODULE=__PROJECT__.settings.production)
# Interpretation: 'check --deploy' flags the production footguns: DEBUG=True (leaks tracebacks/secrets), weak/missing
#                 SECRET_KEY, SECURE_* headers off (HSTS, SSL redirect), permissive ALLOWED_HOSTS. Each (W###) has a
#                 fix in the Django deploy checklist. 'makemigrations --check --dry-run' exiting nonzero = MODELS
#                 CHANGED but migrations weren't generated - deploying that ships a schema mismatch. pip-audit hits =
#                 vulnerable deps.
# Next step:      Fix every W-code from --deploy; generate the missing migrations; patch vulnerable packages

set -euo pipefail

echo "== Production deploy check"
python manage.py check --deploy 2>&1 | grep -E 'WARNING|ERROR|System check' | head -30 || echo "clean"

echo
echo "== Unmade migrations (nonzero exit = model/migration drift)"
if python manage.py makemigrations --check --dry-run >/dev/null 2>&1; then
    echo "migrations: in sync"
else
    echo "DRIFT: models changed without migrations - run makemigrations before deploy"
    python manage.py makemigrations --dry-run 2>/dev/null | head -20
fi

echo
echo "== Dependency vulnerabilities (pip-audit if installed)"
command -v pip-audit >/dev/null && pip-audit 2>/dev/null | head -20 || echo "pip-audit not installed (pip install pip-audit)"
