#!/usr/bin/env bash
# =============================================================================
# triage.sh
# Purpose : First-response incident triage — automated diagnostics snapshot
# Usage   : ./triage.sh [INCIDENT_ID] [--severity P1|P2|P3]
# Author  : Azure DevOps Linux Platform Team
# =============================================================================

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────────────────
INCIDENT_ID="${1:-INC-$(date +%Y%m%d%H%M%S)}"
SEVERITY="P2"
for arg in "$@"; do
  [[ "$arg" =~ ^--severity=(P[123])$ ]] && SEVERITY="${BASH_REMATCH[1]}"
done

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME=$(hostname -f)
REPORT_DIR="/tmp/incident-reports"
REPORT_FILE="${REPORT_DIR}/${INCIDENT_ID}-triage-$(date +%Y%m%d%H%M%S).txt"

mkdir -p "${REPORT_DIR}"

BOLD='\033[1m'; CYAN='\033[0;36m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; RESET='\033[0m'

section() { echo -e "\n${BOLD}${CYAN}── $* ──${RESET}"; }

{
echo "╔══════════════════════════════════════════════════════════╗"
echo "║          INCIDENT TRIAGE REPORT                          ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "  Incident ID : ${INCIDENT_ID}"
echo "  Severity    : ${SEVERITY}"
echo "  Host        : ${HOSTNAME}"
echo "  Timestamp   : ${TIMESTAMP}"
echo "  Triggered by: $(whoami)"
echo "╚══════════════════════════════════════════════════════════╝"

section "1. System Overview"
echo "OS      : $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo "Kernel  : $(uname -r)"
echo "Uptime  : $(uptime -p)"
echo "Last Boot: $(who -b | awk '{print $3, $4}')"

section "2. CPU & Load"
echo "CPU Cores  : $(nproc)"
echo "Load Avg   : $(cat /proc/loadavg)"
echo "CPU Usage  :"
top -bn1 | head -5

section "3. Memory"
free -h

section "4. Disk"
df -h | grep -v tmpfs

section "5. Top 10 CPU-consuming Processes"
ps aux --sort=-%cpu | head -11

section "6. Top 10 Memory-consuming Processes"
ps aux --sort=-%mem | head -11

section "7. Network Connections Summary"
ss -s || netstat -s 2>/dev/null | head -20

section "8. Active Listening Ports"
ss -tlnp || netstat -tlnp 2>/dev/null

section "9. Recent System Logs (last 50 lines)"
journalctl -n 50 --no-pager 2>/dev/null || tail -50 /var/log/syslog 2>/dev/null || echo "N/A"

section "10. Recent Error/Warning Logs"
journalctl -p err -n 30 --no-pager 2>/dev/null || grep -i "error\|warn\|crit" /var/log/syslog 2>/dev/null | tail -30 || echo "N/A"

section "11. Failed Services"
systemctl --failed --no-legend 2>/dev/null || echo "None"

section "12. Disk I/O (iostat)"
iostat -x 1 2 2>/dev/null || echo "iostat not available"

section "13. Open File Descriptors"
lsof 2>/dev/null | wc -l && echo "open file descriptors"

section "14. OOM Killer Events (last 24h)"
grep -i "oom\|killed process" /var/log/kern.log 2>/dev/null | tail -10 || \
  journalctl -k --no-pager -n 20 2>/dev/null | grep -i oom || echo "No OOM events found"

section "15. Azure VM Metadata (if applicable)"
curl -s --connect-timeout 3 \
  "http://169.254.169.254/metadata/instance?api-version=2021-02-01" \
  -H Metadata:true 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Not an Azure VM or metadata unavailable"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Triage report saved: ${REPORT_FILE}"
echo "  Next Step: Review report and follow runbook.md"
echo "════════════════════════════════════════════════════════════"
} | tee "${REPORT_FILE}"

echo -e "\n${BOLD}${CYAN}✅ Triage complete. Report: ${REPORT_FILE}${RESET}"
