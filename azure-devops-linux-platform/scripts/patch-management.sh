#!/usr/bin/env bash
# =============================================================================
# patch-management.sh
# Purpose : Automated Linux patch management — scan, apply, and verify patches
# Usage   : ./patch-management.sh [--dry-run] [--security-only] [--reboot]
# Author  : Azure DevOps Linux Platform Team
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────
LOG_DIR="/var/log/patch-management"
LOG_FILE="${LOG_DIR}/patch-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="/opt/patch-backups"
REPORT_FILE="/tmp/patch-report-$(date +%Y%m%d).txt"

# ── Flags ─────────────────────────────────────────────────────────────────────
DRY_RUN=false
SECURITY_ONLY=false
AUTO_REBOOT=false

for arg in "$@"; do
  case $arg in
    --dry-run)       DRY_RUN=true       ;;
    --security-only) SECURITY_ONLY=true ;;
    --reboot)        AUTO_REBOOT=true   ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log()      { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
log_ok()   { log "${GREEN}✅ $*${RESET}"; }
log_warn() { log "${YELLOW}⚠️  $*${RESET}"; }
log_err()  { log "${RED}❌ $*${RESET}"; }
log_info() { log "${CYAN}ℹ️  $*${RESET}"; }

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}❌ This script must be run as root. Use: sudo $0${RESET}"
  exit 1
fi

mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"
echo "" > "${LOG_FILE}"

log_info "═══════════════════════════════════════════════════════"
log_info " Patch Management — $(hostname) — $(date)"
log_info " Mode: $(${DRY_RUN} && echo 'DRY-RUN' || echo 'APPLY')"
log_info " Scope: $(${SECURITY_ONLY} && echo 'Security Only' || echo 'All Updates')"
log_info "═══════════════════════════════════════════════════════"

# ── Detect Package Manager ────────────────────────────────────────────────────
detect_pkg_manager() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v yum &>/dev/null; then
    echo "yum"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  else
    log_err "Unsupported package manager. Exiting."
    exit 1
  fi
}

PKG_MGR=$(detect_pkg_manager)
log_info "Package Manager: ${PKG_MGR}"

# ── Step 1: Snapshot pre-patch state ─────────────────────────────────────────
log_info "Step 1: Capturing pre-patch state..."
case "${PKG_MGR}" in
  apt)
    dpkg -l > "${BACKUP_DIR}/pre-patch-packages-$(date +%Y%m%d).txt"
    ;;
  yum|dnf)
    ${PKG_MGR} list installed > "${BACKUP_DIR}/pre-patch-packages-$(date +%Y%m%d).txt"
    ;;
esac
log_ok "Pre-patch package list saved to ${BACKUP_DIR}"

# ── Step 2: Check available updates ──────────────────────────────────────────
log_info "Step 2: Checking available updates..."
AVAILABLE_UPDATES=0

case "${PKG_MGR}" in
  apt)
    apt-get update -qq 2>&1 | tee -a "${LOG_FILE}"
    if ${SECURITY_ONLY}; then
      AVAILABLE_UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" | grep -i security || echo "0")
    else
      AVAILABLE_UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || echo "0")
    fi
    ;;
  yum|dnf)
    if ${SECURITY_ONLY}; then
      AVAILABLE_UPDATES=$(${PKG_MGR} check-update --security -q 2>/dev/null | grep -c "^[a-zA-Z]" || echo "0")
    else
      AVAILABLE_UPDATES=$(${PKG_MGR} check-update -q 2>/dev/null | grep -c "^[a-zA-Z]" || echo "0")
    fi
    ;;
esac

log_info "Available updates: ${AVAILABLE_UPDATES}"

if [[ "${AVAILABLE_UPDATES}" -eq 0 ]]; then
  log_ok "System is fully up to date. No patches needed."
  exit 0
fi

# ── Step 3: Apply patches ─────────────────────────────────────────────────────
log_info "Step 3: Applying patches..."

if ${DRY_RUN}; then
  log_warn "DRY-RUN mode: No changes will be made."
  case "${PKG_MGR}" in
    apt)  apt-get -s upgrade 2>&1 | tee -a "${LOG_FILE}" ;;
    yum|dnf) ${PKG_MGR} check-update -q 2>&1 | tee -a "${LOG_FILE}" ;;
  esac
  log_ok "Dry-run complete. ${AVAILABLE_UPDATES} updates would be applied."
else
  log_info "Applying ${AVAILABLE_UPDATES} updates..."
  case "${PKG_MGR}" in
    apt)
      if ${SECURITY_ONLY}; then
        DEBIAN_FRONTEND=noninteractive apt-get -y upgrade \
          -o Dpkg::Options::="--force-confdef" \
          -o Dpkg::Options::="--force-confold" \
          2>&1 | tee -a "${LOG_FILE}"
      else
        DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade \
          -o Dpkg::Options::="--force-confdef" \
          -o Dpkg::Options::="--force-confold" \
          2>&1 | tee -a "${LOG_FILE}"
      fi
      ;;
    yum|dnf)
      if ${SECURITY_ONLY}; then
        ${PKG_MGR} -y update --security 2>&1 | tee -a "${LOG_FILE}"
      else
        ${PKG_MGR} -y update 2>&1 | tee -a "${LOG_FILE}"
      fi
      ;;
  esac
  log_ok "Patch application complete."
fi

# ── Step 4: Post-patch verification ──────────────────────────────────────────
log_info "Step 4: Post-patch verification..."

# Check for held packages (apt) or failed transactions (yum/dnf)
case "${PKG_MGR}" in
  apt)
    HELD=$(apt-mark showhold 2>/dev/null | wc -l)
    if [[ "${HELD}" -gt 0 ]]; then
      log_warn "${HELD} packages are on hold and were NOT updated"
    fi
    ;;
esac

# Verify critical services still running
CRITICAL_SERVICES=("sshd" "cron" "rsyslog")
for svc in "${CRITICAL_SERVICES[@]}"; do
  if systemctl is-active --quiet "${svc}" 2>/dev/null; then
    log_ok "Service ${svc} is running post-patch"
  else
    log_err "Service ${svc} is DOWN post-patch — manual intervention required"
  fi
done

# ── Step 5: Check if reboot required ─────────────────────────────────────────
log_info "Step 5: Checking if reboot is required..."

REBOOT_REQUIRED=false
if [[ -f /var/run/reboot-required ]]; then
  REBOOT_REQUIRED=true
  log_warn "⚠️  REBOOT REQUIRED: /var/run/reboot-required exists"
  if [[ -f /var/run/reboot-required.pkgs ]]; then
    log_info "Packages requiring reboot:"
    cat /var/run/reboot-required.pkgs | tee -a "${LOG_FILE}"
  fi
fi

# ── Step 6: Generate patch report ─────────────────────────────────────────────
log_info "Step 6: Generating patch report..."
{
  echo "Patch Report — $(hostname) — $(date)"
  echo "======================================="
  echo "Mode         : $(${DRY_RUN} && echo 'DRY-RUN' || echo 'APPLIED')"
  echo "Scope        : $(${SECURITY_ONLY} && echo 'Security Only' || echo 'All Updates')"
  echo "Updates      : ${AVAILABLE_UPDATES}"
  echo "Reboot Needed: ${REBOOT_REQUIRED}"
  echo "Log File     : ${LOG_FILE}"
  echo "======================================="
} > "${REPORT_FILE}"

log_ok "Patch report saved to ${REPORT_FILE}"

# ── Step 7: Auto-reboot if flagged ───────────────────────────────────────────
if ${REBOOT_REQUIRED} && ${AUTO_REBOOT}; then
  log_warn "Auto-reboot enabled. Rebooting in 60 seconds..."
  log_warn "Run 'shutdown -c' to cancel."
  shutdown -r +1 "Patch management reboot scheduled"
else
  if ${REBOOT_REQUIRED}; then
    log_warn "Manual reboot required. Schedule during maintenance window."
  fi
fi

log_ok "Patch management completed successfully."
exit 0
