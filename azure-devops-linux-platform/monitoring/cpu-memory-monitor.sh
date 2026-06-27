#!/usr/bin/env bash
# =============================================================================
# cpu-memory-monitor.sh
# Purpose : Real-time CPU and memory monitoring with alerting
# Usage   : ./cpu-memory-monitor.sh [--interval 60] [--alert-email ops@example.com] [--test]
# Author  : Azure DevOps Linux Platform Team
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
INTERVAL=60              # seconds between checks
CPU_WARN=75              # CPU warning threshold (%)
CPU_CRIT=90              # CPU critical threshold (%)
MEM_WARN=80              # Memory warning threshold (%)
MEM_CRIT=95              # Memory critical threshold (%)
ALERT_EMAIL=""
LOG_FILE="/var/log/cpu-memory-monitor.log"
TEST_MODE=false
HOSTNAME=$(hostname -f)

# ── Parse Arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)     INTERVAL="$2";    shift 2 ;;
    --alert-email)  ALERT_EMAIL="$2"; shift 2 ;;
    --test)         TEST_MODE=true;   shift   ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" | tee -a "${LOG_FILE}"
}

send_alert() {
  local SEVERITY="$1"
  local MESSAGE="$2"
  log "ALERT" "[${SEVERITY}] ${MESSAGE}"

  if [[ -n "${ALERT_EMAIL}" ]] && command -v mail &>/dev/null; then
    echo -e "Host: ${HOSTNAME}\nTime: $(date)\nSeverity: ${SEVERITY}\n\n${MESSAGE}" \
      | mail -s "[${SEVERITY}] Alert on ${HOSTNAME}" "${ALERT_EMAIL}"
  fi

  # Azure Monitor custom event (if az CLI available)
  if command -v az &>/dev/null; then
    az monitor metrics alert list --output none 2>/dev/null || true
  fi
}

# ── Get CPU Usage ─────────────────────────────────────────────────────────────
get_cpu_usage() {
  # Read two snapshots of /proc/stat for accurate CPU usage
  local CPU1 CPU2
  CPU1=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)
  sleep 1
  CPU2=$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5}' /proc/stat)

  local TOTAL1 IDLE1 TOTAL2 IDLE2
  TOTAL1=$(echo "${CPU1}" | awk '{print $1}')
  IDLE1=$(echo "${CPU1}"  | awk '{print $2}')
  TOTAL2=$(echo "${CPU2}" | awk '{print $1}')
  IDLE2=$(echo "${CPU2}"  | awk '{print $2}')

  local TOTAL_DIFF IDLE_DIFF
  TOTAL_DIFF=$((TOTAL2 - TOTAL1))
  IDLE_DIFF=$((IDLE2 - IDLE1))

  if [[ "${TOTAL_DIFF}" -gt 0 ]]; then
    echo $(( (TOTAL_DIFF - IDLE_DIFF) * 100 / TOTAL_DIFF ))
  else
    echo 0
  fi
}

# ── Get Memory Usage ──────────────────────────────────────────────────────────
get_mem_usage() {
  awk '/^MemTotal/{total=$2} /^MemAvailable/{avail=$2} END{
    printf "%.0f", (total - avail) * 100 / total
  }' /proc/meminfo
}

get_mem_details() {
  awk '/^MemTotal/{total=$2} /^MemFree/{free=$2} /^MemAvailable/{avail=$2} /^Cached:/{cached=$2} END{
    printf "Total: %.0fMB, Used: %.0fMB, Free: %.0fMB, Available: %.0fMB",
      total/1024, (total-avail)/1024, free/1024, avail/1024
  }' /proc/meminfo
}

# ── Get Top CPU Processes ─────────────────────────────────────────────────────
get_top_cpu_procs() {
  ps aux --sort=-%cpu | awk 'NR<=6 && NR>1 {printf "  PID:%s %s%% %s\n", $2, $3, $11}'
}

# ── Get Top Memory Processes ──────────────────────────────────────────────────
get_top_mem_procs() {
  ps aux --sort=-%mem | awk 'NR<=6 && NR>1 {printf "  PID:%s %s%% %s\n", $2, $4, $11}'
}

# ── Main Monitor Loop ─────────────────────────────────────────────────────────
monitor() {
  log "INFO" "Starting CPU/Memory monitor on ${HOSTNAME} (interval: ${INTERVAL}s)"
  log "INFO" "Thresholds — CPU: WARN=${CPU_WARN}% CRIT=${CPU_CRIT}% | MEM: WARN=${MEM_WARN}% CRIT=${MEM_CRIT}%"

  while true; do
    CPU_PCT=$(get_cpu_usage)
    MEM_PCT=$(get_mem_usage)
    MEM_DETAILS=$(get_mem_details)
    LOAD_AVG=$(awk '{print $1}' /proc/loadavg)
    CPU_COUNT=$(nproc)

    log "INFO" "CPU: ${CPU_PCT}% | MEM: ${MEM_PCT}% (${MEM_DETAILS}) | Load: ${LOAD_AVG}"

    # ── CPU Alerting ──────────────────────────────────────────────────────────
    if [[ "${CPU_PCT}" -ge "${CPU_CRIT}" ]]; then
      TOP_PROCS=$(get_top_cpu_procs)
      send_alert "CRITICAL" "CPU usage is CRITICAL: ${CPU_PCT}%\nTop CPU processes:\n${TOP_PROCS}"
    elif [[ "${CPU_PCT}" -ge "${CPU_WARN}" ]]; then
      TOP_PROCS=$(get_top_cpu_procs)
      send_alert "WARNING" "CPU usage is HIGH: ${CPU_PCT}%\nTop CPU processes:\n${TOP_PROCS}"
    fi

    # ── Memory Alerting ───────────────────────────────────────────────────────
    if [[ "${MEM_PCT}" -ge "${MEM_CRIT}" ]]; then
      TOP_PROCS=$(get_top_mem_procs)
      send_alert "CRITICAL" "Memory usage is CRITICAL: ${MEM_PCT}%\n${MEM_DETAILS}\nTop memory processes:\n${TOP_PROCS}"
    elif [[ "${MEM_PCT}" -ge "${MEM_WARN}" ]]; then
      TOP_PROCS=$(get_top_mem_procs)
      send_alert "WARNING" "Memory usage is HIGH: ${MEM_PCT}%\n${MEM_DETAILS}\nTop memory processes:\n${TOP_PROCS}"
    fi

    if ${TEST_MODE}; then
      log "INFO" "Test mode: one iteration complete. Exiting."
      exit 0
    fi

    sleep "${INTERVAL}"
  done
}

monitor
