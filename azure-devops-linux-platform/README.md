# 🚀 Azure DevOps Linux Platform

A comprehensive infrastructure platform project for **Azure DevOps + Linux** engineering, covering CI/CD pipeline management, Linux system administration, production support, monitoring, incident management, capacity planning, and disaster recovery.

---

## 📁 Project Structure

```
azure-devops-linux-platform/
├── .azure-pipelines/           # Azure DevOps CI/CD pipeline definitions
│   ├── ci-pipeline.yml         # Continuous Integration pipeline
│   ├── cd-pipeline.yml         # Continuous Deployment pipeline
│   └── templates/              # Reusable pipeline templates
├── scripts/                    # Linux shell scripts
│   ├── system-health-check.sh  # System health diagnostics
│   ├── patch-management.sh     # Automated patching script
│   ├── user-management.sh      # User provisioning/deprovisioning
│   └── log-rotation.sh         # Log management
├── monitoring/                 # System performance monitoring
│   ├── cpu-memory-monitor.sh   # CPU/Memory alerting
│   ├── disk-monitor.sh         # Disk usage monitoring
│   └── network-monitor.sh      # Network monitoring
├── incident-management/        # Production support & incident response
│   ├── runbook.md              # Incident runbook
│   ├── triage.sh               # First-response triage script
│   └── escalation-matrix.md    # Escalation procedures
├── capacity-planning/          # Capacity and resource planning
│   ├── capacity-report.sh      # Resource utilization report
│   └── capacity-planning.md    # Planning documentation
├── disaster-recovery/          # DR scripts and playbooks
│   ├── dr-playbook.md          # Disaster recovery playbook
│   ├── backup.sh               # Automated backup script
│   └── restore.sh              # Restore script
├── networking/                 # Network configuration & diagnostics
│   ├── network-diag.sh         # Network diagnostics
│   └── firewall-rules.sh       # Firewall rule management
├── docs/                       # Infrastructure documentation
│   ├── architecture.md         # System architecture
│   ├── onboarding.md           # Team onboarding guide
│   └── compliance.md           # Compliance and audit docs
└── README.md
```

---

## 🛠️ Tech Stack

| Category | Technology |
|---|---|
| CI/CD Platform | Azure DevOps Pipelines |
| OS | Linux (RHEL / Ubuntu) |
| Scripting | Bash / Shell |
| Cloud | Microsoft Azure |
| IaC | Terraform / ARM Templates |
| Monitoring | Azure Monitor, Custom Scripts |
| Incident Mgmt | PagerDuty / ServiceNow |
| Version Control | Git / Azure Repos |

---

## 🚦 Getting Started

### Prerequisites
- Azure CLI installed: `az --version`
- Azure DevOps organization access
- Linux environment (RHEL 8+/Ubuntu 20.04+)
- Bash 4.0+

### Setup
```bash
# Clone the repository
git clone https://github.com/arunk-eng/cloud-platform-engineering.git
cd cloud-platform-engineering/azure-devops-linux-platform

# Make scripts executable
chmod +x scripts/*.sh monitoring/*.sh incident-management/*.sh \
         capacity-planning/*.sh disaster-recovery/*.sh networking/*.sh

# Run system health check
./scripts/system-health-check.sh
```

---

## 📋 Key Features

- **CI/CD Automation**: Multi-stage Azure DevOps pipelines with approval gates
- **Linux Production Support**: Automated triage, health checks, and patching
- **Monitoring & Alerting**: Real-time CPU, memory, disk, and network monitoring
- **Incident Management**: Structured runbooks and escalation procedures
- **Capacity Planning**: Resource utilization tracking and forecasting
- **Disaster Recovery**: Automated backup, restore, and DR playbooks
- **Documentation**: Full compliance and knowledge-sharing docs

---

## 📞 Support & Escalation

See [incident-management/escalation-matrix.md](incident-management/escalation-matrix.md) for escalation procedures and on-call contacts.

---

## 📄 License

MIT License — See [LICENSE](../LICENSE) for details.
