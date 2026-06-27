# Project 2: AI-Driven Terraform Policy & Cost Reviewer

The **AI-Driven Terraform Policy & Cost Reviewer** acts as an automated Pull Request (PR) reviewer. It intercepts pull requests proposing changes to AWS infrastructure, parses the `terraform plan` changes, and calls an LLM to generate security and cost reviews.

---

## 🏗️ Architecture Design

```
Developer PR -> GitHub Actions -> Terraform Plan -> JSON Output -> AI Reviewer -> PR Comment
```

---

## 📋 The Review Process

1. **Static Scans**: TFLint/Checkov run first to perform static code analysis.
2. **Plan Generation**: The workflow runs `terraform plan -out=tfplan`.
3. **JSON Conversion**: The binary plan is converted to JSON to allow parsing:
   ```bash
   terraform show -json tfplan > plan.json
   ```
4. **AI Evaluation**: The python agent ([ai_reviewer.py](../ai-terraform-reviewer/ai_reviewer.py)) parses the plan, counts created/modified/deleted resources, and builds an instruction prompt containing the details.
5. **PR Annotation**: The markdown report is printed to standard output and uploaded as a PR comment in GitHub.

---

## 💻 Infrastructure Under Review

The provided Terraform module provisions a secure Amazon EKS (Elastic Kubernetes Service) cluster on AWS:
- **VPC & Subnets**: Multi-AZ public and private subnets.
- **NAT Gateway**: Single NAT Gateway for private subnet outbound internet access.
- **KMS Key**: Custom KMS key with rotation enabled, used to encrypt EKS secrets.
- **Node Group**: Auto-scaling managed nodes (`t3.medium`).

---

## 🚀 How to Run & Verify

### Local Review Generation
1. Install dependencies:
   ```bash
   pip install -r ai-terraform-reviewer/requirements.txt
   ```
2. Create a mock plan or pass an existing plan JSON:
   ```bash
   python ai-terraform-reviewer/ai_reviewer.py --plan plan.json --output review.md
   ```
   *Expected Result: The script output details security vulnerabilities (like EKS public endpoints) and cost suggestions (NAT Gateway usage and instance scaling).*
