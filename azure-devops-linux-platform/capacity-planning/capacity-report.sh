#!/usr/bin/env bash
# =============================================================================
# capacity-report.sh
# Purpose : Resource utilization report for capacity planning
# Usage   : ./capacity-report.sh [--days 7] [--output /tmp/capacity-report.txt]
# Author  : Azure DevOps Linux Platform Team
# =============================================================================

set -euo pipefail

DAYS=7
OUTPUT="/tmp/capacity-report-$(date +%Y%m%d).txt"

for arg in "$@"; do
  case "$arg" in
    --days)   DAYS="$2"   ;;
    --output) OUTPUT="$2" ;;
  esac
done

HOSTNAME=$(hostname -f)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CPU_COUNT=$(nproc)
MEM_TOTAL_MB=$(awk '/^MemTotal/{print int($2/1024)}' /proc/meminfo)

{
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         CAPACITY PLANNING REPORT                         ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "  Host      : ${HOSTNAME}"
echo "  Report    : ${TIMESTAMP}"
echo "  Period    : Last ${DAYS} days"
echo "╚══════════════════════════════════════════════════════════╝"

echo ""
echo "─── Hardware ─────────────────────────────────────────────"
echo "CPU Cores    : ${CPU_COUNT}"
echo "CPU Model    : $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "Total RAM    : ${MEM_TOTAL_MB} MB"
echo "Architecture : $(uname -m)"

echo ""
echo "─── Current Resource Utilization ─────────────────────────"
MEM_USED_MB=$(free -m | awk '/^Mem:/{print $3}')
MEM_PCT=$(echo "scale=1; ${MEM_USED_MB} * 100 / ${MEM_TOTAL_MB}" | bc)
echo "Memory Used  : ${MEM_USED_MB} MB / ${MEM_TOTAL_MB} MB (${MEM_PCT}%)"
echo ""

echo "Disk Utilization:"
df -h | awk 'NR==1 || !/tmpfs|udev/' | column -t
echo ""

echo "─── Load Average History ──────────────────────────────────"
echo "Current Load : $(cat /proc/loadavg)"
if command -v sar &>/dev/null; then
  echo "CPU History (sar):"
  sar -u "${DAYS}" 2>/dev/null | tail -5 || echo "  sar data not available for ${DAYS} days"
else
  echo "  Install 'sysstat' for historical CPU data (yum/apt install sysstat)"
fi

echo ""
echo "─── Swap Utilization ──────────────────────────────────────"
free -h | grep Swap

echo ""
echo "─── Network Interfaces ────────────────────────────────────"
ip -s link show | awk '/^[0-9]+: /{iface=$2} /RX:/{getline; print iface, "RX:", $1, "bytes"} /TX:/{getline; print iface, "TX:", $1, "bytes"}' | grep -v "^lo" | head -20

echo ""
echo "─── Top Disk-using Directories ────────────────────────────"
du -sh /var /tmp /home /opt /usr 2>/dev/null | sort -rh | head -10

echo ""
echo "─── Process Count ─────────────────────────────────────────"
echo "Total Processes  : $(ps aux | wc -l)"
echo "Running          : $(ps aux | awk '$8=="R"' | wc -l)"
echo "Sleeping         : $(ps aux | awk '$8=="S"' | wc -l)"

echo ""
echo "─── Azure VM SKU (if applicable) ──────────────────────────"
curl -s --connect-timeout 3 \
  "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01" \
  -H Metadata:true 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'VM Size: {d.get(\"vmSize\",\"N/A\")}\nLocation: {d.get(\"location\",\"N/A\")}\nSKU: {d.get(\"sku\",\"N/A\")}')" \
  2>/dev/null || echo "  Not running on Azure VM or metadata unavailable"

echo ""
echo "─── Recommendations ───────────────────────────────────────"
MEM_PCT_INT=${MEM_PCT%.*}
[[ "${MEM_PCT_INT}" -gt 85 ]] && echo "⚠️  Memory usage is high (${MEM_PCT}%) — Consider scaling up VM or optimizing workloads"
[[ "${MEM_PCT_INT}" -lt 30 ]] && echo "💡 Memory usage is low (${MEM_PCT}%) — Consider downsizing VM to reduce cost"

while IFS= read -r line; do
  DISK_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
  MOUNT=$(echo "$line" | awk '{print $6}')
  [[ "${DISK_PCT}" -gt 80 ]] && echo "⚠️  Disk ${MOUNT} at ${DISK_PCT}% — Expand volume or clean up"
  [[ "${DISK_PCT}" -lt 20 ]] && echo "💡 Disk ${MOUNT} at ${DISK_PCT}% — Underutilized, consider reducing"
done < <(df -h | awk 'NR>1 && !/tmpfs|udev/')

echo ""
echo "Report saved to: ${OUTPUT}"
echo "═══════════════════════════════════════════════════════════"
} | tee "${OUTPUT}"

echo "✅ Capacity report complete: ${OUTPUT}"
