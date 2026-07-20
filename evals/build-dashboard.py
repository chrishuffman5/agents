#!/usr/bin/env python3
"""Generate docs/results.js for the GitHub Pages dashboard.

Reads:
  - evals/results/*-summary.csv           (agent + baseline eval runs)
  - evals/suites/*.json                   (task counts, ground-truth citations)
  - plugins/<domain>/skills/**/scripts/*  (shipped diagnostic script coverage)

Emits docs/results.js as `window.DASHBOARD_DATA = {...}` so the page renders
over file:// and GitHub Pages alike (no fetch/CORS). Re-run after each eval sweep.

Usage:  python evals/build-dashboard.py
"""
import csv
import json
import glob
import os
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RESULTS = REPO / "evals" / "results"
SUITES = REPO / "evals" / "suites"
PLUGINS = REPO / "plugins"
OUT = REPO / "docs" / "results.js"

# Domain display metadata: title + one-line description + category grouping.
DOMAINS = {
    "database":        ("Database", "29 engines across relational, document, key-value, graph, search, time-series, OLAP", "Data"),
    "analytics":       ("Analytics & BI", "Power BI, Tableau, Looker, SSAS/SSRS, Superset, Grafana, ThoughtSpot", "Data"),
    "etl":             ("ETL & Pipelines", "Airflow, dbt, Spark, SSIS, ADF, Glue, Fivetran, NiFi", "Data"),
    "storage":         ("Storage", "NetApp ONTAP, Pure, Ceph, MinIO, S3, Azure Blob, GCS", "Infrastructure"),
    "os":              ("Operating Systems", "Windows Server/Client, RHEL, Ubuntu, Debian, SLES, macOS", "Infrastructure"),
    "virtualization":  ("Virtualization", "VMware, Proxmox, KVM, Nutanix, Citrix, cloud VMs", "Infrastructure"),
    "containers":      ("Containers", "Kubernetes, EKS/AKS/GKE, Helm, Docker, service mesh", "Infrastructure"),
    "networking":      ("Networking", "Routing, firewalls, DNS, load balancing, VPN, SD-WAN, wireless", "Infrastructure"),
    "cloud-platforms": ("Cloud Platforms", "AWS, Azure, GCP architecture, migration, FinOps", "Infrastructure"),
    "monitoring":      ("Monitoring", "Prometheus, Grafana, ELK, OpenTelemetry, Datadog, PagerDuty", "Operations"),
    "devops":          ("DevOps", "CI/CD, IaC, config management, GitOps, version control", "Operations"),
    "cli-scripting":   ("CLI & Scripting", "PowerShell, Bash, Python, Node.js, AWS/Azure CLI, kubectl", "Operations"),
    "security":        ("Security", "IAM, EDR, SIEM, secrets, cloud/app/network security, DLP, zero trust", "Operations"),
    "messaging":       ("Messaging", "Kafka, RabbitMQ, Pulsar, NATS, SQS/SNS, Service Bus, Pub/Sub", "Application"),
    "api-realtime":    ("API & Real-Time", "REST, GraphQL, gRPC, OData, WebSocket, SSE, SignalR", "Application"),
    "backend":         ("Backend", "ASP.NET Core, Spring Boot, Django, Rails, Express, FastAPI, Go, Rust", "Application"),
    "frontend":        ("Frontend", "React, Next.js, Vue, Angular, Svelte, Astro, Blazor", "Application"),
    "mail-collab":     ("Mail & Collaboration", "Exchange, Microsoft 365, Google Workspace, Postfix", "Application"),
}

SCRIPT_EXTS = {".sql", ".ps1", ".sh", ".js"}


def num(v):
    try:
        f = float(v)
        return int(f) if f == int(f) else round(f, 3)
    except (TypeError, ValueError):
        return None


def load_runs():
    """Return {(suite, mode): row} keeping the newest run per suite+mode.

    Run recency comes from the timestamped filename prefix, so a later sweep
    supersedes an earlier one for the same suite.
    """
    best = {}
    for path in sorted(glob.glob(str(RESULTS / "*-summary.csv"))):
        stamp = os.path.basename(path).split("-summary")[0]
        with open(path, newline="") as fh:
            for row in csv.DictReader(fh):
                # Skip the harness-defect run where everything scored 0 tokens.
                if num(row.get("mean_out_tokens")) in (0, None) and num(row.get("solved")) == 0:
                    continue
                key = (row["suite"], row["mode"])
                if key not in best or stamp > best[key][0]:
                    best[key] = (stamp, row)
    return {k: v[1] for k, v in best.items()}


def count_scripts(domain):
    """Count shipped script files and the technologies that carry them."""
    base = PLUGINS / domain / "skills"
    if not base.exists():
        return 0, []
    techs = {}
    for p in base.rglob("*"):
        if p.suffix in SCRIPT_EXTS and p.parent.name == "scripts":
            # tech = the skill directory above scripts/ (or version/tech above that)
            rel = p.relative_to(base)
            tech = rel.parts[0] if rel.parts else "?"
            techs[tech] = techs.get(tech, 0) + 1
    total = sum(techs.values())
    tech_list = [f"{t} ({n})" for t, n in sorted(techs.items(), key=lambda kv: -kv[1])]
    return total, tech_list


def count_tech_dirs(domain):
    """Best-effort technology count = immediate skill subdirs excluding references/scripts."""
    base = PLUGINS / domain / "skills"
    if not base.exists():
        return None
    skip = {"references", "scripts"}
    return sum(1 for d in base.iterdir() if d.is_dir() and d.name not in skip)


def suite_task_count(domain):
    f = SUITES / f"{domain}.json"
    if not f.exists():
        return None
    return len(json.loads(f.read_text()).get("tasks", []))


def build():
    runs = load_runs()
    domains = []
    for slug, (title, desc, category) in DOMAINS.items():
        agent = runs.get((slug, "agent"))
        base = runs.get((slug, "baseline"))
        scripts, tech_list = count_scripts(slug)

        def pack(row):
            if not row:
                return None
            return {
                "tasks": num(row["tasks"]),
                "solved": num(row["solved"]),
                "passAt1": num(row["pass_at_1"]),
                "meanAttempts": num(row["mean_attempts"]),
                "meanTokens": num(row["mean_out_tokens"]),
                "meanWallS": num(row["mean_wall_s"]),
                "costUsd": num(row["total_cost_usd"]),
            }

        domains.append({
            "slug": slug,
            "title": title,
            "description": desc,
            "category": category,
            "technologies": count_tech_dirs(slug),
            "taskCount": suite_task_count(slug),
            "scripts": scripts,
            "scriptTechs": tech_list,
            "agent": pack(agent),
            "baseline": pack(base),
        })

    # Portfolio rollup from the fair agent-vs-baseline sweep (same task sets).
    def rollup(mode):
        rows = [d[mode] for d in domains if d.get(mode)]
        tasks = sum(r["tasks"] for r in rows)
        solved = sum(r["solved"] for r in rows)
        # pass@1 weighted by tasks
        p1 = sum(r["passAt1"] * r["tasks"] for r in rows) / tasks if tasks else 0
        return {"suites": len(rows), "tasks": tasks, "solved": solved,
                "passAt1": round(p1, 3)}

    data = {
        "generated": os.environ.get("DASHBOARD_STAMP", ""),
        "totals": {
            "domains": len(domains),
            "scripts": sum(d["scripts"] for d in domains),
            "agent": rollup("agent"),
            "baseline": rollup("baseline"),
        },
        "domains": domains,
    }
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(
        "// AUTO-GENERATED by evals/build-dashboard.py — do not edit by hand.\n"
        "// Re-run `python evals/build-dashboard.py` after each eval sweep.\n"
        "window.DASHBOARD_DATA = " + json.dumps(data, indent=2) + ";\n"
    )
    print(f"Wrote {OUT.relative_to(REPO)}")
    print(f"  {len(domains)} domains, {data['totals']['scripts']} scripts")
    print(f"  agent:    {data['totals']['agent']}")
    print(f"  baseline: {data['totals']['baseline']}")


if __name__ == "__main__":
    build()
