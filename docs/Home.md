# 📖 DevOps + AI Wiki Home

Welcome to the internal engineering wiki for the **DevOps & AI Systems Integration Portfolio**. This wiki serves as the central documentation repository for understanding, deploying, and maintaining the AI-driven automation components in this project.

---

## 🗺️ Wiki Sitemap

### 🔍 Project-Specific Guides
1. [Project 1: AI-Powered Kubernetes Log Analyzer](Project-1-K8s-Log-Analyzer.md)
   * Kubernetes CronJob, API monitoring, logs/events parsing, and LLM integrations.
2. [Project 2: AI-Driven Terraform Policy & Cost Reviewer](Project-2-Terraform-Reviewer.md)
   * Terraform JSON plans, static code scans, automated security/cost audits, and PR comments.
3. [Project 3: Self-Healing CI/CD Pipeline](Project-3-Self-Healing-CI.md)
   * Automated failure trace identification, source code patching, and git verification.
4. [Project 4: AWS Bedrock Log Diagnostics Agent](Project-4-AWS-Bedrock-Diagnostics.md)
   * CloudWatch Subscriptions, serverless Python Lambda, Bedrock Converse APIs, and SNS alert dispatching.

---

## 🛠️ Global Prerequisites & Setup

To run these tools locally, ensure the following tools are installed:

- **Python 3.10+**: Runtime environment for all AI scripts.
- **Docker**: For testing the K8s analyzer image.
- **Terraform 1.5.0+**: Infrastructure provisioning engine.
- **kubectl**: Kubernetes CLI tool configured to point to a test cluster (e.g. Minikube, Kind).

### 🔑 AI API Credentials Setup
To activate full AI functionality, configure one or both of the following environment variables:

```bash
# For Google Gemini Models (e.g. gemini-1.5-flash)
export GEMINI_API_KEY="your-gemini-api-key"

# For OpenAI Models (e.g. gpt-4o-mini)
export OPENAI_API_KEY="your-openai-api-key"
export OPENAI_MODEL_NAME="gpt-4o-mini" # Optional, defaults to gpt-4o-mini
```

For AWS Bedrock components:
```bash
# Ensure AWS credentials are loaded
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

*(Note: If no API keys are provided, the scripts gracefully degrade to **dry-run demo modes** to facilitate local verification and pipeline testing).*
