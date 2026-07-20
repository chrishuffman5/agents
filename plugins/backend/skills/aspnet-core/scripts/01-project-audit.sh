#!/usr/bin/env bash
# Purpose:        ASP.NET Core project audit - target frameworks, vulnerable/outdated/deprecated packages, and build health
# Applies to:     ASP.NET Core on .NET 8/9/10 (dotnet SDK; run in the solution/project directory)
# Read-only:      yes (restore/list only; no code changes)
# Inputs:         run from the directory containing the .sln or .csproj
# Interpretation: 'list package --vulnerable' with any GHSA hits = fix before shipping (transitive ones need the
#                 --include-transitive view - a safe direct dep can pull a vulnerable one). --deprecated names
#                 packages with no security future. --outdated shows how far behind you are; a major-version gap on
#                 the framework (net6.0 in a net8-era app) is EOL risk. Multiple TargetFrameworks across projects =
#                 a migration mid-flight - finish it.
# Next step:      dotnet add package to patch vulnerable/deprecated deps; plan the framework bump if EOL

set -euo pipefail

echo "== Target frameworks in the solution"
grep -rhoE '<TargetFramework[s]?>[^<]+' --include='*.csproj' . | sed 's/<[^>]*>//g' | sort | uniq -c

echo
echo "== Restore"
dotnet restore >/dev/null 2>&1 && echo "restore: OK" || { echo "restore FAILED - fix before auditing packages"; exit 1; }

echo
echo "== Vulnerable packages (incl. transitive)"
dotnet list package --vulnerable --include-transitive 2>/dev/null | grep -E '>|GHSA|CVE|has the following' | head -30 || echo "none reported"

echo
echo "== Deprecated packages"
dotnet list package --deprecated 2>/dev/null | grep '>' | head -15 || echo "none"

echo
echo "== Outdated (major gaps first)"
dotnet list package --outdated 2>/dev/null | grep '>' | head -20 || echo "all current"
