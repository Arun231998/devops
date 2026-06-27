# Disaster Recovery Playbook
# Azure DevOps Linux Platform

## Overview

This playbook defines the procedures for recovering the Azure DevOps Linux Platform in the event of a disaster. It covers recovery objectives, procedures for different failure scenarios, and contact information.

---

## Recovery Objectives

| Metric | Target |
|--------|--------|
| **RTO** (Recovery Time Objective) | 4 hours |
| **RPO** (Recovery Point Objective) | 1 hour |
| **Backup Frequency** | Every 6 hours |
| **Backup Retention** | 30 days |
| **DR Test Frequency** | Quarterly |

---

## Disaster Scenarios

### Scenario 1: Single VM Failure

**Symptoms**: One Linux VM unresponsive, Azure health alerts triggered.

**Recovery Steps**:

1. **Detect**: Azure Monitor alert fires → on-call notified via PagerDuty
2. **Assess**: Verify VM state in Azure Portal
   ```bash
   az vm show -g <resource-group> -n <vm-name> --query powerState
   ```
3. **Restart VM** (if VM is stopped/deallocated):
   ```bash
   az vm start -g <resource-group> -n <vm-name>
   ```
4. **Redeploy VM** (if corruption suspected):
   ```bash
   az vm redeploy -g <resource-group> -n <vm-name>
   ```
5. **Restore from backup** if data corrupted:
   ```bash
   sudo ./disaster-recovery/restore.sh \
     --backup-file /mnt/backup/<hostname>-backup-<timestamp>.tar.gz \
     --target /opt/linux-platform
   ```
6. **Verify** with health check:
   ```bash
   ./scripts/system-health-check.sh
   ```
7. **Re-run CD pipeline** to re-deploy platform scripts

**RTO**: ~30 minutes

---

### Scenario 2: Region-Wide Azure Outage

**Symptoms**: Multiple services unavailable; Azure status page shows region incident.

**Recovery Steps**:

1. **Declare DR event** → notify stakeholders
2. **Activate secondary region** (paired region deployment):
   ```bash
   az group deployment create \
     --resource-group rg-linux-platform-secondary \
     --template-file infrastructure/arm-template.json \
     --parameters @infrastructure/params-secondary.json
   ```
3. **Update DNS** to point to secondary region:
   ```bash
   az network dns record-set a update \
     --resource-group rg-dns \
     --zone-name example.com \
     --record-set-name platform \
     --set aRecords[0].ipv4Address=<secondary-ip>
   ```
4. **Restore latest backup** to secondary environment
5. **Update Azure DevOps agent pools** to use secondary agents
6. **Communicate** recovery status to stakeholders

**RTO**: ~4 hours

---

### Scenario 3: Ransomware / Data Corruption

**Symptoms**: Files encrypted, unusual disk activity, services failing.

**Recovery Steps**:

1. **IMMEDIATELY isolate** affected VMs:
   ```bash
   # Remove from load balancer
   az network lb address-pool address remove \
     --resource-group <rg> \
     --lb-name <lb-name> \
     --pool-name <pool> \
     --name <vm-nic>

   # Block all network access (Azure NSG emergency rule)
   az network nsg rule create \
     --resource-group <rg> \
     --nsg-name <nsg-name> \
     --name EMERGENCY-BLOCK-ALL \
     --priority 100 \
     --direction Inbound \
     --access Deny \
     --protocol '*' \
     --source-address-prefixes '*' \
     --destination-port-ranges '*'
   ```
2. **Preserve forensic evidence** — do NOT restart yet
3. **Notify security team** and management
4. **Restore clean backup** to a new VM:
   ```bash
   # Deploy fresh VM
   az vm create \
     --resource-group <rg> \
     --name <new-vm-name> \
     --image UbuntuLTS \
     --admin-username azureuser \
     --ssh-key-values ~/.ssh/id_rsa.pub

   # Restore from last known good backup
   sudo ./disaster-recovery/restore.sh \
     --backup-file /mnt/backup/<hostname>-backup-<timestamp>.tar.gz
   ```
5. **Re-deploy from source control** via Azure DevOps pipeline

**RTO**: ~8 hours (+ security review)

---

## Backup Schedule (Crontab)

```cron
# Backup every 6 hours
0 */6 * * * root /opt/linux-platform/disaster-recovery/backup.sh --azure >> /var/log/backup.log 2>&1

# Daily full backup at midnight
0 0 * * * root /opt/linux-platform/disaster-recovery/backup.sh --azure --dest /mnt/backup/daily >> /var/log/backup.log 2>&1

# Weekly backup on Sunday at 2am
0 2 * * 0 root /opt/linux-platform/disaster-recovery/backup.sh --azure --dest /mnt/backup/weekly >> /var/log/backup.log 2>&1
```

---

## DR Test Checklist (Quarterly)

- [ ] Verify backup files exist and checksums pass
- [ ] Restore backup to isolated test environment
- [ ] Verify all services start correctly after restore
- [ ] Test CD pipeline re-deployment to clean VM
- [ ] Test DNS failover to secondary region
- [ ] Measure actual RTO and compare to target
- [ ] Update runbook with any findings
- [ ] Document test results and sign-off

---

## Key Contacts

| Role | Name | Contact |
|------|------|---------|
| DR Lead | On-call Engineer | PagerDuty |
| Azure Platform | Cloud Team | #azure-platform Slack |
| Security | SecOps Team | security@example.com |
| Management | Engineering Manager | escalation-matrix.md |
