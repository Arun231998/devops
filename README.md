# 🤖 DevOps + AI Engineer Portfolio

Welcome to the **DevOps & AI Systems Engineering Portfolio**. This repository showcases production-grade integrations of Large Language Models (LLMs) with core DevOps practices, including Infrastructure as Code (IaC), GitOps, self-healing continuous integration (CI) workflows, and cloud monitoring.

---

## 🏗️ Architecture & Workflows

```mermaid
graph TD
    %% Project 1: Kubernetes Log Analyzer
    subgraph K8s [Kubernetes Monitoring (Project 1)]
        Pod[Failing App Pod] -->|Logs & Events| CronJob[AI Log Analyzer CronJob]
        CronJob -->|Analyze Logs| LLM1[Gemini/OpenAI API]
        LLM1 -->|Remediation & Commands| CronJob
        CronJob -->|Report Diagnostic| Syslogs[Terminal/Log Console]
    end

    %% Project 2: AI Terraform Reviewer
    subgraph IaC [AI Terraform Reviewer (Project 2)]
        PR[Developer PR] -->|Trigger CI| GH1[GitHub Actions]
        GH1 -->|Terraform Plan JSON| Reviewer[AI Plan Reviewer Script]
        Reviewer -->|Inspect Config| LLM2[Gemini/OpenAI API]
        LLM2 -->|Security & Cost Audit| Reviewer
        Reviewer -->|Publish Comments| PR
    end

    %% Project 3: Self-Healing CI/CD
    subgraph Healing [Self-Healing CI/CD (Project 3)]
        Code[Source Code] -->|Pushed to Main| GH2[GitHub Actions]
        GH2 -->|Run Pytest| TestResult[Failing Tests]
        TestResult -->|Auto-Trigger| Healer[AI Self-Healer Script]
        Healer -->|Log & Source Analysis| LLM3[Gemini/OpenAI API]
        LLM3 -->|Generated Patch| Healer
        Healer -->|Apply Auto-Fix| Code
    end

    style K8s fill:#f9f9f9,stroke:#333,stroke-width:1px
    style IaC fill:#f9f9f9,stroke:#333,stroke-width:1px
    style Healing fill:#f9f9f9,stroke:#333,stroke-width:1px
```

---

## 🚀 Projects Included

### 1. AI-Powered Kubernetes Log Analyzer (`ai-k8s-log-analyzer`)
A Kubernetes native agent that monitors pod lifecycles, detects application crashes, retrieves container logs, and analyzes root causes via LLM integration.

* **Core Code**: [main.py](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/ai-k8s-log-analyzer/main.py)
* **Configuration**: [k8s-manifests.yaml](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/ai-k8s-log-analyzer/k8s-manifests.yaml) — Sets up the RBAC permissions (`ClusterRole`, `ServiceAccount`) and runs the analyzer as a `CronJob`.
* **CI/CD Pipeline**: [log-analyzer-ci.yml](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/.github/workflows/log-analyzer-ci.yml)
* **Local Run**:
  ```bash
  cd ai-k8s-log-analyzer
  pip install -r requirements.txt
  python main.py --namespace default
  ```
  *(If no API keys are supplied, the script runs in a **dry-run demo mode** returning realistic Kubernetes errors and fixes).*

---

### 2. AI-Driven Terraform Policy & Cost Reviewer (`ai-terraform-reviewer`)
An automated Pull Request reviewer for Infrastructure as Code (IaC) that audits EKS clusters, networking setups, and storage resources for security vulnerabilities and cost inefficiencies.

* **Terraform Module**: [main.tf](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/ai-terraform-reviewer/terraform/main.tf) — Provisions AWS VPC, NAT Gateway, subnets, KMS key encryption, and EKS Cluster.
* **Analyzer Script**: [ai_reviewer.py](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/ai-terraform-reviewer/ai_reviewer.py) — Parses JSON plans and calls AI models to write feedback.
* **CI/CD Pipeline**: [terraform-ci.yml](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/.github/workflows/terraform-ci.yml)
* **Local Run**:
  ```bash
  cd ai-terraform-reviewer
  # Install dependencies
  pip install -r requirements.txt
  
  # Run the reviewer on a simulated plan
  python ai_reviewer.py --plan ../.github/workflows/terraform-ci.yml --output review_output.md
  ```

---

### 3. Self-Healing CI/CD Pipeline (`ai-self-healing-ci`)
A failure-recovery system that hooks into pipeline stages. If a test fails, the agent parses the console output/stack traces, locates the buggy file, queries the AI to write a patch, and applies the fix directly to the repository.

* **Fixing Agent**: [self_healer.py](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/ai-self-healing-ci/self_healer.py)
* **Deliberately Failing Test**: [test_app.py](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/ai-self-healing-ci/test_app.py) — Contains a failing assertion to demonstrate auto-repair.
* **CI/CD Pipeline**: [self-healing-ci.yml](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/.github/workflows/self-healing-ci.yml)
* **Demo Run (No Keys Required)**:
  ```bash
  cd ai-self-healing-ci
  pip install -r requirements.txt
  
  # Run tests to generate a failing log
  pytest test_app.py > test.log 2>&1
  
  # Execute Self-Healer (automatically updates test_app.py assert)
  python self_healer.py --logs test.log --file test_app.py
  
  # Verify test_app.py is healed and passes
  pytest test_app.py
  ```

---

## 🗄️ Legacy Experiments
Existing configurations and trial pipelines have been archived inside [legacy-experiments/](file:///Users/Arunkumar/.gemini/antigravity/scratch/devops/legacy-experiments/) to keep the main development root clean and clean of boilerplate templates.
