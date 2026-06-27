# System Architecture — Azure DevOps Linux Platform

## Overview

This document describes the infrastructure architecture for the Azure DevOps Linux Platform, covering compute, networking, CI/CD, monitoring, and DR topology.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AZURE DEVOPS ORGANIZATION                         │
│                                                                           │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────────────┐  │
│  │  CI Pipeline │──▶│ CD Pipeline  │──▶│  Environments                │  │
│  │              │   │              │   │  DEV → STAGING → PROD        │  │
│  │ - Lint       │   │ - Deploy     │   │  (with approval gates)       │  │
│  │ - Sec Scan   │   │ - Health Chk │   └──────────────────────────────┘  │
│  │ - Build      │   │ - Rollback   │                                      │
│  └──────────────┘   └──────────────┘                                      │
└─────────────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────────┐
              │               │                   │
              ▼               ▼                   ▼
   ┌─────────────────┐ ┌────────────────┐ ┌───────────────────┐
   │  DEV Region     │ │ STAGING Region │ │ PRODUCTION Region │
   │  East US        │ │  East US       │ │  East US          │
   │                 │ │                │ │  (Primary)        │
   │ ┌─────────────┐ │ │ ┌────────────┐ │ │ ┌───────────────┐ │
   │ │ Linux VM(s) │ │ │ │ Linux VM(s)│ │ │ │  Linux VMs    │ │
   │ │ Ubuntu 22   │ │ │ │ Ubuntu 22  │ │ │ │  (Scale Set)  │ │
   │ └─────────────┘ │ │ └────────────┘ │ │ └───────────────┘ │
   │                 │ │                │ │         │         │
   └─────────────────┘ └────────────────┘ │  ┌──────▼──────┐  │
                                           │  │ Azure LB    │  │
                                           │  └─────────────┘  │
                                           └───────────────────┘
                                                    │
                                           ┌────────▼────────┐
                                           │  DR REGION      │
                                           │  West US        │
                                           │  (Secondary)    │
                                           └─────────────────┘
```

---

## Components

### Compute

| Component | Specification | Count |
|-----------|--------------|-------|
| Dev VMs | Standard_B2s (2 vCPU, 4GB RAM) | 1 |
| Staging VMs | Standard_D2s_v3 (2 vCPU, 8GB RAM) | 2 |
| Production VMs | Standard_D4s_v3 (4 vCPU, 16GB RAM) | 3+ (autoscale) |
| Agent VMs | Standard_B2ms | 2 (per pool) |

### Networking

```
Internet
    │
    ▼
[Azure Front Door / Application Gateway]
    │
    ▼
[Azure Load Balancer — Public]
    │
    ▼
[Network Security Group (NSG)]
    │
    ├── Allow: 443 (HTTPS) inbound
    ├── Allow: 22 (SSH) from jump box only
    ├── Deny: All other inbound
    │
    ▼
[Virtual Network: 10.0.0.0/16]
    ├── Subnet: compute (10.0.1.0/24)
    ├── Subnet: agents  (10.0.2.0/24)
    └── Subnet: mgmt    (10.0.3.0/24)
```

### Storage

| Purpose | Type | Tier |
|---------|------|------|
| OS Disks | Azure Managed Disk | Premium SSD |
| Data Disks | Azure Managed Disk | Standard SSD |
| Backup Storage | Azure Blob Storage | Cool |
| Artifacts | Azure Artifact Feed | Standard |

### Monitoring Stack

- **Azure Monitor** — VM metrics, alerts, dashboards
- **Log Analytics Workspace** — Centralized log collection
- **Azure Alerts** — CPU/Memory/Disk thresholds → PagerDuty
- **Custom Scripts** — `monitoring/cpu-memory-monitor.sh`

---

## Security

| Control | Implementation |
|---------|---------------|
| Authentication | Azure AD + SSH key pairs |
| Authorization | RBAC (Azure + Linux sudoers) |
| Network | NSG + Azure Firewall |
| Secrets | Azure Key Vault |
| Patching | `scripts/patch-management.sh` (automated) |
| Audit Logs | Azure Activity Log + auditd |
| Vulnerability Scan | Trivy in CI pipeline |
| Secret Scan | detect-secrets in CI pipeline |
