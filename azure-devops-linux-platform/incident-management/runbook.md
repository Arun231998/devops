# Incident Runbook — Azure DevOps Linux Platform

## Overview
This runbook provides structured procedures for responding to production incidents on Linux-based infrastructure managed via Azure DevOps.

---

## Severity Levels

| Severity | Impact | Response SLA | Escalation |
|----------|--------|-------------|------------|
| **P1** | Full outage, revenue impact | 15 minutes | On-call Lead + Manager |
| **P2** | Partial outage, degraded performance | 30 minutes | On-call Engineer |
| **P3** | Minor issue, no user impact | 4 hours | Next business day |
| **P4** | Cosmetic / informational | Best effort | Ticket queue |

---

## Incident Response Steps

### Step 1: Detect & Triage (0–15 min)

1. Acknowledge alert in PagerDuty/ServiceNow
2. Run automated triage:
   ```bash
   sudo ./incident-management/triage.sh INC-<ticket-id> --severity P1
   ```
3. Review triage report for immediate indicators
4. Open communication bridge (Teams/Slack war room)

### Step 2: Diagnose (15–30 min)

Run targeted diagnostics based on symptom:

#### High CPU
```bash
# Identify top processes
top -b -n1 | head -20
ps aux --sort=-%cpu | head -10

# Check for runaway processes
pidstat -u 1 5

# Review cron jobs
crontab -l && ls /etc/cron.*
```

#### High Memory / OOM
```bash
# Check memory
free -h && vmstat -s

# OOM events
journalctl -k | grep -i oom | tail -20

# Memory by process
ps aux --sort=-%mem | head -10
cat /proc/meminfo
```

#### Disk Full
```bash
# Find largest files/dirs
du -sh /* 2>/dev/null | sort -rh | head -20
df -h

# Find files modified recently
find / -mtime -1 -size +100M -not -path "/proc/*" 2>/dev/null

# Clean up old logs
sudo journalctl --vacuum-time=7d
sudo find /var/log -name "*.log" -mtime +30 -delete
```

#### Network Issues
```bash
# Check connectivity
ping -c 4 8.8.8.8
traceroute management.azure.com

# Check listening services
ss -tlnp

# Check firewall
sudo firewall-cmd --list-all  # RHEL
sudo ufw status               # Ubuntu

# Active connections
ss -s
```

#### Service Down
```bash
# Check service status
systemctl status <service-name>

# View recent service logs
journalctl -u <service-name> -n 50 --no-pager

# Restart service (with caution in production)
sudo systemctl restart <service-name>
```

### Step 3: Mitigate (30–60 min)

Common mitigation actions:

| Issue | Mitigation |
|-------|-----------|
| High CPU | Kill/renice runaway process; scale up VM |
| Memory pressure | Restart memory-leaking service; add swap |
| Disk full | Clean logs/tmp; expand disk |
| Service crash | Restart service; check config for errors |
| Network timeout | Check NSG rules; verify DNS resolution |
| Failed deployment | Roll back via CD pipeline re-run |

### Step 4: Communicate

Update stakeholders every 30 minutes during active P1/P2 incidents:

```
[INCIDENT UPDATE] INC-XXXXX | Severity: P1
Status: <Investigating | Mitigating | Monitoring>
Impact: <What is affected>
ETA: <Expected resolution time>
Actions taken: <What has been done>
Next update: <Time of next update>
```

### Step 5: Resolve & Document

1. Confirm resolution with monitoring
2. Run post-resolution health check:
   ```bash
   ./scripts/system-health-check.sh
   ```
3. Update incident ticket with root cause and timeline
4. Schedule Post-Incident Review (PIR) for P1/P2 within 48 hours
5. Document lessons learned and create follow-up action items

---

## Common Azure DevOps Pipeline Issues

### Pipeline Stuck / Not Triggered
```bash
# Check agent pool status
az pipelines agent list --pool-id <pool-id> --org <org-url>

# Re-queue failed run
az pipelines run --id <pipeline-id> --org <org-url> --project <project>
```

### Agent Offline
```bash
# Check agent service on Linux VM
sudo systemctl status vsts.agent.*
sudo systemctl restart vsts.agent.*

# View agent logs
cat /home/azureuser/agent/_diag/Agent_*.log | tail -100
```

### Deployment Failure — Rollback
```bash
# Trigger rollback via CD pipeline with previous artifact
az pipelines run \
  --id <cd-pipeline-id> \
  --parameters "ROLLBACK=true ARTIFACT_VERSION=<prev-build>" \
  --org <org-url> --project <project>
```

---

## Escalation Matrix

See [escalation-matrix.md](escalation-matrix.md) for full contact details.

---

## Post-Incident Review Template

```
PIR — Incident: INC-XXXXX
Date: 
Severity: 
Duration: 

## Summary
Brief description of the incident.

## Timeline
- HH:MM - Alert triggered
- HH:MM - On-call acknowledged
- HH:MM - Root cause identified
- HH:MM - Mitigation applied
- HH:MM - Incident resolved

## Root Cause
What caused the incident?

## Impact
- Users affected:
- Services affected:
- Data loss: Yes/No

## What Went Well
- 

## What Went Wrong
- 

## Action Items
| Item | Owner | Due Date |
|------|-------|----------|
| | | |
```
