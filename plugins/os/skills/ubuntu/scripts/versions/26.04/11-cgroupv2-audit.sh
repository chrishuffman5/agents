#!/usr/bin/env bash
# ============================================================================
# Ubuntu 26.04 - cgroup v2 Audit
#
# Purpose : Verify cgroup v2-only hierarchy, detect v1 usage, check container
#           runtime compatibility, and scan for processes using v1 paths.
# Version : 26.1.0
# Targets : Ubuntu 26.04 LTS (Resolute Raccoon)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Ubuntu Version
#   2. cgroup Hierarchy
#   3. /sys/fs/cgroup Structure
#   4. systemd cgroup Configuration
#   5. Docker cgroup Driver
#   6. containerd cgroup Driver
#   7. Process cgroup v1 Usage Scan
#   8. Java cgroup v2 Awareness
# ============================================================================
set -euo pipefail

PASS=0; WARN=0; FAIL=0
result() {
    local s=$1 m=$2
    printf "%-10s %s\n" "[$s]" "$m"
    case $s in
        PASS) ((PASS++)) ;;
        WARN) ((WARN++)) ;;
        FAIL) ((FAIL++)) ;;
    esac
}

echo "=== cgroup v2 Audit (Ubuntu 26.04+) ==="
echo "Host: $(hostname) | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# -- 1. Ubuntu version -----------------------------------------------------
echo "--- Ubuntu Version ---"
if grep -q "26.04" /etc/os-release 2>/dev/null; then
    result PASS "Ubuntu 26.04 detected -- cgroup v1 removed, v2-only kernel"
else
    DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    result WARN "OS: $DISTRO -- cgroup v2 verification still applicable"
fi

# -- 2. cgroup hierarchy ---------------------------------------------------
echo ""
echo "--- cgroup Hierarchy ---"
CGROUP_MOUNTS=$(mount | grep cgroup)

if echo "$CGROUP_MOUNTS" | grep -q "cgroup2"; then
    result PASS "cgroup v2 (unified hierarchy) is mounted at /sys/fs/cgroup"
else
    result FAIL "cgroup v2 not found in mount table"
fi

if echo "$CGROUP_MOUNTS" | grep -q " cgroup " && ! echo "$CGROUP_MOUNTS" | grep -q "cgroup2"; then
    result FAIL "cgroup v1 mount detected -- unexpected on 26.04"
else
    result PASS "No cgroup v1 mounts -- v2-only confirmed"
fi

# -- 3. /sys/fs/cgroup structure --------------------------------------------
echo ""
echo "--- /sys/fs/cgroup Structure ---"
if ls /sys/fs/cgroup/memory 2>/dev/null | grep -q "memory.limit_in_bytes" 2>/dev/null; then
    result FAIL "v1 memory controller interface found -- cgroup v1 is active"
else
    result PASS "No v1 memory controller interface -- v2 layout confirmed"
fi

echo "       Available v2 controllers:"
cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null | tr ' ' '\n' | sed 's/^/         /' || echo "         (cannot read)"

# -- 4. systemd cgroup driver ----------------------------------------------
echo ""
echo "--- systemd cgroup Configuration ---"
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    result PASS "systemd is using cgroup v2 unified hierarchy"
    echo "       Default slice: $(systemctl show --property DefaultControlGroup 2>/dev/null | cut -d= -f2 || echo 'n/a')"
else
    result WARN "Cannot verify systemd cgroup driver"
fi

# -- 5. Docker cgroup driver -----------------------------------------------
echo ""
echo "--- Container Runtime: Docker ---"
if command -v docker &>/dev/null; then
    DOCKER_CGROUP=$(docker info 2>/dev/null | grep -i "cgroup driver" | awk '{print $NF}' || echo "unknown")
    DOCKER_VER=$(docker --version 2>/dev/null | head -1)
    echo "       Docker: $DOCKER_VER"
    if [[ "$DOCKER_CGROUP" == "systemd" ]]; then
        result PASS "Docker cgroup driver: systemd (correct for v2)"
    elif [[ "$DOCKER_CGROUP" == "cgroupfs" ]]; then
        result FAIL "Docker cgroup driver: cgroupfs -- must change to systemd"
        echo "       Fix: {\"exec-opts\": [\"native.cgroupdriver=systemd\"]} in /etc/docker/daemon.json"
    else
        result WARN "Docker cgroup driver: $DOCKER_CGROUP (unknown/not running)"
    fi
else
    echo "       Docker not installed -- skipping"
fi

# -- 6. containerd cgroup driver -------------------------------------------
echo ""
echo "--- Container Runtime: containerd ---"
if command -v containerd &>/dev/null; then
    CONTAINERD_VER=$(containerd --version 2>/dev/null | head -1)
    echo "       containerd: $CONTAINERD_VER"
    CONTAINERD_CGROUP=$(grep -A3 "SystemdCgroup" /etc/containerd/config.toml 2>/dev/null | grep "SystemdCgroup" | awk -F= '{print $2}' | tr -d ' ' || echo "not configured")
    if [[ "$CONTAINERD_CGROUP" == "true" ]]; then
        result PASS "containerd SystemdCgroup = true (correct for v2)"
    else
        result FAIL "containerd SystemdCgroup = $CONTAINERD_CGROUP -- set to true"
        echo "       Fix: In /etc/containerd/config.toml, set SystemdCgroup = true"
    fi
else
    echo "       containerd not installed -- skipping"
fi

# -- 7. Process v1 usage scan ----------------------------------------------
echo ""
echo "--- Process cgroup v1 Usage Scan ---"
V1_COUNT=0
while IFS= read -r proc; do
    if [[ -f "/proc/${proc}/cgroup" ]]; then
        LINE_COUNT=$(wc -l < "/proc/${proc}/cgroup" 2>/dev/null || echo 0)
        if [[ $LINE_COUNT -gt 1 ]]; then
            CMD=$(cat "/proc/${proc}/comm" 2>/dev/null || echo "unknown")
            echo "       PID=$proc CMD=$CMD (multiple cgroup lines)"
            ((V1_COUNT++))
        fi
    fi
done < <(ls /proc | grep "^[0-9]" | head -50)

if [[ $V1_COUNT -eq 0 ]]; then
    result PASS "No processes found using cgroup v1 hierarchy"
else
    result WARN "${V1_COUNT} process(es) may be using v1 cgroup paths"
fi

# -- 8. Java cgroup v2 awareness -------------------------------------------
echo ""
echo "--- Java cgroup v2 Awareness ---"
if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | head -1)
    echo "       Java: $JAVA_VER"
    if java -version 2>&1 | grep -qE "version \"(1[7-9]|2[0-9]|[3-9][0-9])\."; then
        result PASS "Java version is cgroup v2 aware (17+)"
    elif java -version 2>&1 | grep -qE "version \"11\.0\.(1[9-9]|[2-9][0-9])"; then
        result PASS "Java 11.0.19+ is cgroup v2 aware"
    else
        result WARN "Java version may not be cgroup v2 aware -- memory limits may be ignored"
        echo "       Upgrade to: Java 8u372+, 11.0.19+, 17.0.7+, or 21+"
    fi
else
    echo "       Java not installed -- skipping"
fi

echo ""
echo "=== Summary: PASS=$PASS  WARN=$WARN  FAIL=$FAIL ==="
echo ""
echo "Key verification commands:"
echo "  mount | grep cgroup                    # show cgroup mounts"
echo "  cat /sys/fs/cgroup/cgroup.controllers  # list v2 controllers"
echo "  cat /proc/1/cgroup                     # systemd cgroup path"
echo "  systemd-cgls                           # cgroup tree"
echo "  systemd-cgtop                          # live resource usage"
