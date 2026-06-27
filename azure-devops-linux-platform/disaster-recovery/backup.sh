#!/usr/bin/env bash
# =============================================================================
# backup.sh
# Purpose : Automated backup script for disaster recovery
# Usage   : ./backup.sh [--target /data] [--dest /mnt/backup] [--azure]
# Author  : Azure DevOps Linux Platform Team
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SOURCE_DIRS=("/etc" "/opt/linux-platform" "/home" "/var/log")
DEST_DIR="/mnt/backup"
RETENTION_DAYS=30
AZURE_BACKUP=false
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:-}"
AZURE_CONTAINER="${AZURE_CONTAINER:-backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOSTNAME=$(hostname -s)
BACKUP_NAME="${HOSTNAME}-backup-${TIMESTAMP}"
BACKUP_FILE="/tmp/${BACKUP_NAME}.tar.gz"
LOG_FILE="/var/log/backup.log"

# ── Parse Args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)  SOURCE_DIRS=("$2"); shift 2 ;;
    --dest)    DEST_DIR="$2";      shift 2 ;;
    --azure)   AZURE_BACKUP=true;  shift   ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }

log "═══════════════════════════════════════════════════"
log " Backup started: ${BACKUP_NAME}"
log " Sources: ${SOURCE_DIRS[*]}"
log " Destination: ${DEST_DIR}"
log "═══════════════════════════════════════════════════"

# ── Step 1: Create backup archive ─────────────────────────────────────────────
log "Step 1: Creating compressed backup archive..."
tar -czf "${BACKUP_FILE}" \
  --warning=no-file-changed \
  "${SOURCE_DIRS[@]}" 2>/dev/null || true

BACKUP_SIZE=$(du -sh "${BACKUP_FILE}" | awk '{print $1}')
log "✅ Archive created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# ── Step 2: Calculate checksum ────────────────────────────────────────────────
log "Step 2: Computing SHA256 checksum..."
CHECKSUM=$(sha256sum "${BACKUP_FILE}" | awk '{print $1}')
echo "${CHECKSUM}  ${BACKUP_NAME}.tar.gz" > "${BACKUP_FILE}.sha256"
log "✅ Checksum: ${CHECKSUM}"

# ── Step 3: Copy to local destination ────────────────────────────────────────
log "Step 3: Copying to local backup destination..."
mkdir -p "${DEST_DIR}"
cp "${BACKUP_FILE}" "${DEST_DIR}/"
cp "${BACKUP_FILE}.sha256" "${DEST_DIR}/"
log "✅ Backup copied to ${DEST_DIR}"

# ── Step 4: Upload to Azure Blob Storage (optional) ──────────────────────────
if ${AZURE_BACKUP}; then
  log "Step 4: Uploading to Azure Blob Storage..."
  if ! command -v az &>/dev/null; then
    log "❌ Azure CLI not found. Skipping Azure upload."
  elif [[ -z "${AZURE_STORAGE_ACCOUNT}" ]]; then
    log "❌ AZURE_STORAGE_ACCOUNT not set. Skipping Azure upload."
  else
    az storage blob upload \
      --account-name "${AZURE_STORAGE_ACCOUNT}" \
      --container-name "${AZURE_CONTAINER}" \
      --name "${BACKUP_NAME}.tar.gz" \
      --file "${BACKUP_FILE}" \
      --auth-mode login \
      --overwrite true
    log "✅ Uploaded to Azure: ${AZURE_CONTAINER}/${BACKUP_NAME}.tar.gz"
  fi
fi

# ── Step 5: Enforce retention policy ─────────────────────────────────────────
log "Step 5: Enforcing ${RETENTION_DAYS}-day retention policy..."
find "${DEST_DIR}" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete
find "${DEST_DIR}" -name "*.sha256" -mtime +${RETENTION_DAYS} -delete
REMAINING=$(ls -1 "${DEST_DIR}"/*.tar.gz 2>/dev/null | wc -l || echo 0)
log "✅ Retention applied. ${REMAINING} backup(s) retained."

# ── Step 6: Verify backup integrity ──────────────────────────────────────────
log "Step 6: Verifying backup integrity..."
cd "${DEST_DIR}"
if sha256sum -c "${BACKUP_NAME}.tar.gz.sha256" &>/dev/null; then
  log "✅ Backup integrity verified."
else
  log "❌ Backup integrity check FAILED!"
  exit 1
fi

# ── Cleanup temp file ─────────────────────────────────────────────────────────
rm -f "${BACKUP_FILE}" "${BACKUP_FILE}.sha256"

log "═══════════════════════════════════════════════════"
log "✅ Backup complete: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"
log "═══════════════════════════════════════════════════"
