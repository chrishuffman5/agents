#!/usr/bin/env python3
"""
============================================================================
Python - Cross-Platform System Report

Purpose : Collect OS, CPU, memory, disk, and network information.
          Outputs structured text or JSON report.
Version : 1.0.0
Targets : Python 3.10+
Requires: psutil (optional -- graceful fallback if not installed)
Safety  : Read-only. No system modifications.

Usage:
  python3 01-system-report.py
  python3 01-system-report.py -f json -o report.json
============================================================================
"""

import argparse
import json
import platform
import socket
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False


def collect_os() -> dict:
    u = platform.uname()
    return {
        "system": u.system, "hostname": u.node, "release": u.release,
        "version": u.version, "machine": u.machine, "python": platform.python_version(),
    }


def collect_network() -> dict:
    hostname = socket.gethostname()
    try:
        ip = socket.gethostbyname(hostname)
    except socket.gaierror:
        ip = "unknown"
    return {"hostname": hostname, "primary_ip": ip, "fqdn": socket.getfqdn()}


def collect_cpu() -> dict:
    if not HAS_PSUTIL:
        return {"available": False}
    return {
        "available": True, "physical": psutil.cpu_count(logical=False),
        "logical": psutil.cpu_count(logical=True),
        "percent_1s": psutil.cpu_percent(interval=1),
    }


def collect_memory() -> dict:
    if not HAS_PSUTIL:
        return {"available": False}
    vm = psutil.virtual_memory()
    swap = psutil.swap_memory()
    return {
        "available": True,
        "ram_total_gb": round(vm.total / 1e9, 2),
        "ram_used_gb": round(vm.used / 1e9, 2),
        "ram_percent": vm.percent,
        "swap_total_gb": round(swap.total / 1e9, 2),
        "swap_used_gb": round(swap.used / 1e9, 2),
    }


def collect_disk() -> list[dict]:
    if not HAS_PSUTIL:
        return []
    disks = []
    for part in psutil.disk_partitions():
        try:
            usage = psutil.disk_usage(part.mountpoint)
            disks.append({
                "device": part.device, "mountpoint": part.mountpoint,
                "fstype": part.fstype, "total_gb": round(usage.total / 1e9, 2),
                "used_gb": round(usage.used / 1e9, 2), "percent": usage.percent,
            })
        except PermissionError:
            pass
    return disks


def collect_top_processes(n: int = 5) -> list[dict]:
    if not HAS_PSUTIL:
        return []
    procs = []
    for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_info"]):
        try:
            info = proc.info
            procs.append({
                "pid": info["pid"], "name": info["name"],
                "cpu_pct": info["cpu_percent"] or 0.0,
                "mem_mb": round((info["memory_info"].rss if info["memory_info"] else 0) / 1e6, 1),
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    return sorted(procs, key=lambda p: p["mem_mb"], reverse=True)[:n]


def build_report() -> dict:
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "os": collect_os(), "network": collect_network(),
        "cpu": collect_cpu(), "memory": collect_memory(),
        "disks": collect_disk(), "top_processes": collect_top_processes(),
        "psutil_installed": HAS_PSUTIL,
    }


def print_text_report(report: dict) -> None:
    sep = "-" * 60
    print(f"\n{'SYSTEM REPORT':^60}")
    print(sep)
    print(f"Generated : {report['generated_at']}")

    os_info = report["os"]
    print(f"\nOS")
    print(f"  System   : {os_info['system']} {os_info['release']}")
    print(f"  Hostname : {os_info['hostname']}")
    print(f"  Machine  : {os_info['machine']}")
    print(f"  Python   : {os_info['python']}")

    net = report["network"]
    print(f"\nNETWORK")
    print(f"  IP   : {net['primary_ip']}")
    print(f"  FQDN : {net['fqdn']}")

    cpu = report["cpu"]
    if cpu.get("available"):
        print(f"\nCPU")
        print(f"  Cores : {cpu['physical']} physical / {cpu['logical']} logical")
        print(f"  Usage : {cpu['percent_1s']}%")

    mem = report["memory"]
    if mem.get("available"):
        print(f"\nMEMORY")
        print(f"  RAM  : {mem['ram_used_gb']:.1f} / {mem['ram_total_gb']:.1f} GB ({mem['ram_percent']}%)")
        print(f"  Swap : {mem['swap_used_gb']:.1f} / {mem['swap_total_gb']:.1f} GB")

    if report["disks"]:
        print(f"\nDISKS")
        print(f"  {'Device':<20} {'Mount':<15} {'Used':>8} {'Total':>8} {'Pct':>6}")
        for d in report["disks"]:
            print(f"  {d['device']:<20} {d['mountpoint']:<15} "
                  f"{d['used_gb']:>7.1f}G {d['total_gb']:>7.1f}G {d['percent']:>5.1f}%")

    if report["top_processes"]:
        print(f"\nTOP PROCESSES")
        print(f"  {'PID':>7}  {'Name':<25} {'MEM MB':>8}")
        for p in report["top_processes"]:
            print(f"  {p['pid']:>7}  {p['name']:<25} {p['mem_mb']:>8.1f}")
    print()


def main() -> None:
    parser = argparse.ArgumentParser(description="Cross-platform system report")
    parser.add_argument("-f", "--format", choices=["text", "json"], default="text")
    parser.add_argument("-o", "--output", type=Path, metavar="FILE")
    args = parser.parse_args()

    if not HAS_PSUTIL:
        print("Warning: psutil not installed. pip install psutil", file=sys.stderr)

    report = build_report()
    if args.format == "json":
        output = json.dumps(report, indent=2)
    else:
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            print_text_report(report)
        output = buf.getvalue()

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
        print(f"Report written to {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
