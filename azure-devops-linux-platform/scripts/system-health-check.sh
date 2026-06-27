#!/usr/bin/env bash
# =============================================================================
# system-health-check.sh
# Purpose : Comprehensive Linux system health diagnostics for production support
# Usage   : ./system-health-check.sh [--json] [--alert]
# Author  : Azure DevOps Linux Platform Team
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Thresholds ────────────────────────────────────────────────────────────────
CPU_THRESHOLD=85       # % CPU usage warning
MEM_THRESHOLD=90       # % Memory usage warning
DISK_THRESHOLD=85      # % Disk usage warning
LOAD_MULTIPLIER=2      # Load avg warning = CPU_COUNT × multiplier

# ── Flags ─────────────────────────────────────────────────────────────────────
JSON_OUTPUT=false
ALERT_MODE=false
ISSUES=0

for arg in "$@"; do
  case $arg in
    --json)  JSON_OUTPUT=true  ;;
    --alert) ALERT_MODE=true   ;;
  esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────
log_ok()   { echo -e "${GREEN}  ✅ $*${RESET}"; }
log_warn() { echo -e "${YELLOW}  ⚠️  $*${RESET}"; ((ISSUES++)); }
log_err()  { echo -e "${RED}  ❌ $*${RESET}"; ((ISSUES++)); }
log_info() { echo -e "${CYAN}  ℹ️  $*${RESET}"; }
section()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${RESET}"; \
             echo -e "${BOLD}${CYAN}  $*${RESET}"; \
             echo -e "${BOLD}${CYAN}══════════════════════════════════════${RESET}"; }

HOSTNAME=$(hostname -f)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OS_INFO=$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
UPTIME=$(uptime -p)

# ─────────────────────────────────────────────────────────────────────────────
section "🖥️  System Health Report — ${HOSTNAME}"
echo -e "  Timestamp : ${TIMESTAMP}"
echo -e "  OS        : ${OS_INFO}"
echo -e "  Kernel    : ${KERNEL}"
echo -e "  Uptime    : ${UPTIME}"

# ── 1. CPU Check ──────────────────────────────────────────────────────────────
section "1. CPU Usage"
CPU_COUNT=$(nproc)
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%us,' || echo "0")
CPU_USAGE=$(echo "100 - ${CPU_IDLE}" | bc 2>/dev/null || awk "BEGIN{print 100 - ${CPU_IDLE}}")
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1}')
LOAD_WARN=$(echo "${CPU_COUNT} * ${LOAD_MULTIPLIER}" | bc)

log_info "CPU Cores    : ${CPU_COUNT}"
log_info "CPU Usage    : ${CPU_USAGE}%"
log_info "Load Avg(1m) : ${LOAD_AVG} (warn > ${LOAD_WARN})"

if (( $(echo "${CPU_USAGE} > ${CPU_THRESHOLD}" | bc -l) )); then
  log_warn "High CPU usage: ${CPU_USAGE}% (threshold: ${CPU_THRESHOLD}%)"
else
  log_ok "CPU usage is normal: ${CPU_USAGE}%"
fi

if (( $(echo "${LOAD_AVG} > ${LOAD_WARN}" | bc -l) )); then
  log_warn "High load average: ${LOAD_AVG}"
else
  log_ok "Load average is normal: ${LOAD_AVG}"
fi

# ── 2. Memory Check ───────────────────────────────────────────────────────────
section "2. Memory Usage"
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m  | awk '/^Mem:/{print $3}')
MEM_FREE=$(free -m  | awk '/^Mem:/{print $4}')
MEM_PCT=$(echo "scale=1; ${MEM_USED} * 100 / ${MEM_TOTAL}" | bc)
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
SWAP_USED=$(free -m  | awk '/^Swap:/{print $3}')

log_info "Total Memory : ${MEM_TOTAL} MB"
log_info "Used Memory  : ${MEM_USED} MB (${MEM_PCT}%)"
log_info "Free Memory  : ${MEM_FREE} MB"
log_info "Swap Used    : ${SWAP_USED} MB / ${SWAP_TOTAL} MB"

if (( $(echo "${MEM_PCT} > ${MEM_THRESHOLD}" | bc -l) )); then
  log_err "Critical memory usage: ${MEM_PCT}% (threshold: ${MEM_THRESHOLD}%)"
else
  log_ok "Memory usage is normal: ${MEM_PCT}%"
fi

if [[ "${SWAP_TOTAL}" -gt 0 && "${SWAP_USED}" -gt 0 ]]; then
  SWAP_PCT=$(echo "scale=1; ${SWAP_USED} * 100 / ${SWAP_TOTAL}" | bc)
  if (( $(echo "${SWAP_PCT} > 50" | bc -l) )); then
    log_warn "Swap usage is high: ${SWAP_PCT}%"
  else
    log_ok "Swap usage is normal: ${SWAP_PCT}%"
  fi
fi

# ── 3. Disk Check ─────────────────────────────────────────────────────────────
section "3. Disk Usage"
while IFS= read -r line; do
  USAGE=$(echo "$line" | awk '{print $5}' | tr -d '%')
  MOUNT=$(echo "$line" | awk '{print $6}')
  FS=$(echo "$line"    | awk '{print $1}')
  log_info "Filesystem: ${FS} → Mounted: ${MOUNT} → Used: ${USAGE}%"
  if [[ "${USAGE}" -ge "${DISK_THRESHOLD}" ]]; then
    log_err "Disk usage CRITICAL on ${MOUNT}: ${USAGE}% (threshold: ${DISK_THRESHOLD}%)"
  else
    log_ok "Disk OK on ${MOUNT}: ${USAGE}%"
  fi
done < <(df -h | awk 'NR>1 && $1 !~ /^(tmpfs|devtmpfs|udev)/' | grep -v "0%")

# ── 4. Services Check ─────────────────────────────────────────────────────────
section "4. Critical Services"
SERVICES=("sshd" "cron" "rsyslog" "firewalld")

for svc in "${SERVICES[@]}"; do
  if systemctl is-active --quiet "${svc}" 2>/dev/null; then
    log_ok "Service ${svc} is RUNNING"
  else
    log_warn "Service ${svc} is NOT running"
  fi
done

# ── 5. Network Check ──────────────────────────────────────────────────────────
section "5. Network Connectivity"
INTERFACES=$(ip -o link show | awk -F': ' '!/lo/{print $2}')
for iface in ${INTERFACES}; do
  STATE=$(cat /sys/class/net/"${iface}"/operstate 2>/dev/null || echo "unknown")
  if [[ "${STATE}" == "up" ]]; then
    log_ok "Interface ${iface} is UP"
  else
    log_warn "Interface ${iface} state: ${STATE}"
  fi
done

# Internet connectivity
if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
  log_ok "Internet connectivity: OK"
else
  log_err "No internet connectivity"
fi

# Azure endpoint reachability
if curl -s --connect-timeout 5 https://management.azure.com/ &>/dev/null; then
  log_ok "Azure Management API: reachable"
else
  log_warn "Azure Management API: unreachable"
fi

# ── 6. Recent Failed Logins ───────────────────────────────────────────────────
section "6. Security — Failed Logins (last 24h)"
FAILED=$(lastb 2>/dev/null | grep -c "$(date +%b)" || echo "0")
log_info "Failed login attempts today: ${FAILED}"
if [[ "${FAILED}" -gt 20 ]]; then
  log_warn "High number of failed login attempts: ${FAILED}"
else
  log_ok "Failed login count is within normal range: ${FAILED}"
fi

# ── 7. Zombie Processes ───────────────────────────────────────────────────────
section "7. Zombie Processes"
ZOMBIES=$(ps aux | grep -c 'Z' || echo "0")
if [[ "${ZOMBIES}" -gt 0 ]]; then
  log_warn "Zombie processes detected: ${ZOMBIES}"
  ps aux | awk '$8=="Z"{print "  PID:", $2, "CMD:", $11}'
else
  log_ok "No zombie processes detected"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
section "📊 Health Check Summary"
if [[ "${ISSUES}" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  ✅ ALL CHECKS PASSED — System is healthy${RESET}"
  exit 0
elif [[ "${ISSUES}" -le 2 ]]; then
  echo -e "${YELLOW}${BOLD}  ⚠️  ${ISSUES} WARNING(S) detected — Review recommended${RESET}"
  exit 1
else
  echo -e "${RED}${BOLD}  ❌ ${ISSUES} ISSUE(S) detected — Immediate attention required${RESET}"
  exit 2
fi
