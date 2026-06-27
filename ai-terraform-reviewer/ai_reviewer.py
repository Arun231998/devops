import os
import sys
import json
import logging
import argparse
from typing import Dict, Any, List

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("tf-ai-reviewer")

class TFPlanAIReviewer:
    def __init__(self):
        self.gemini_key = os.getenv("GEMINI_API_KEY")
        self.openai_key = os.getenv("OPENAI_API_KEY")
        self.provider = None

        if self.gemini_key:
            self.provider = "gemini"
            import google.generativeai as genai
            genai.configure(api_key=self.gemini_key)
            self.model = genai.GenerativeModel("gemini-1.5-flash")
            logger.info("Using Google Gemini API as AI provider.")
        elif self.openai_key:
            self.provider = "openai"
            from openai import OpenAI
            self.client = OpenAI(api_key=self.openai_key)
            self.model_name = os.getenv("OPENAI_MODEL_NAME", "gpt-4o-mini")
            logger.info(f"Using OpenAI API ({self.model_name}) as AI provider.")
        else:
            logger.warning("No GEMINI_API_KEY or OPENAI_API_KEY found. Running in DRY-RUN demo mode.")
            self.provider = "dry-run"

    def parse_plan(self, plan_file: str) -> Dict[str, Any]:
        """Parses the json representation of the terraform plan."""
        logger.info(f"Reading Terraform plan JSON from: {plan_file}")
        try:
            with open(plan_file, 'r') as f:
                plan_data = json.load(f)
        except Exception as e:
            logger.error(f"Failed to read or parse plan file: {e}")
            sys.exit(1)

        # Extract summary details
        changes = {
            "create": 0,
            "update": 0,
            "delete": 0,
            "resources_changed": []
        }

        resource_changes = plan_data.get("resource_changes", [])
        for rc in resource_changes:
            actions = rc.get("change", {}).get("actions", [])
            addr = rc.get("address", "")
            type_ = rc.get("type", "")

            if "create" in actions:
                changes["create"] += 1
                changes["resources_changed"].append(f"[CREATE] {addr} ({type_})")
            elif "delete" in actions:
                changes["delete"] += 1
                changes["resources_changed"].append(f"[DELETE] {addr} ({type_})")
            elif "update" in actions:
                changes["update"] += 1
                changes["resources_changed"].append(f"[UPDATE] {addr} ({type_})")

        return changes

    def generate_review(self, plan_summary: Dict[str, Any]) -> str:
        summary_str = json.dumps(plan_summary, indent=2)
        
        prompt = f"""
You are an expert Cloud Architect and DevOps Security Reviewer. Analyze the following summary of changes from a Terraform Plan:

---
{summary_str}
---

Generate a comprehensive PR Review Comment in Markdown with the following sections:
1. **Executive Summary**: High-level overview of changes (creation, updates, deletion counts).
2. **Security Evaluation**: Check if any resources present security issues (e.g. open ports, unencrypted components, root privileges, lack of KMS).
3. **Cost Optimization**: Detail the cost implications of the proposed changes (e.g. provisioned NAT Gateways, EC2 instances, EKS Node counts) and identify savings.
4. **Architectural Recommendations**: Recommendations to improve tags, modularity, or resilience.

Use alerts (e.g. > [!IMPORTANT] for security concerns, > [!WARNING] for cost warnings) to highlight critical findings. Keep the tone helpful, professional, and technical.
"""

        if self.provider == "dry-run":
            # Return high-quality, professional markdown simulating what Gemini/OpenAI would reply for EKS
            return """# 🤖 AI Terraform Plan Review

## 📋 Executive Summary
* **Resources to Create**: 17
* **Resources to Update**: 0
* **Resources to Delete**: 0

The plan proposes provisioning a full Kubernetes EKS infrastructure (VPC, subnets, NAT gateway, KMS keys, IAM policies, and EKS Node groups).

---

## 🔒 Security Evaluation
> [!IMPORTANT]
> **EKS Public Access Enabled**
> `aws_eks_cluster.main` enables `endpoint_public_access = true`. In production environments, it is recommended to set `endpoint_public_access = false` or restrict inbound IP CIDRs via `public_access_cidrs` to avoid exposing the Kubernetes control plane API to the open internet.

> [!TIP]
> **KMS Rotation Enabled**
> Great job enabling `enable_key_rotation = true` on `aws_kms_key.eks_kms`. This satisfies security compliance standard ISO/IEC 27001.

---

## 💰 Cost Optimization
> [!WARNING]
> **Provisioned NAT Gateway Cost**
> The plan creates a single Elastic IP and NAT Gateway. NAT Gateways cost ~$0.045/hour plus data processing fees. Consider using VPC endpoints (PrivateLink) for S3, ECR, and SSM to reduce NAT Gateway data transit charges.
>
> **EC2 Instance Sizing**
> The node group scales up to 4 `t3.medium` instances. If the workload is small or non-prod, consider switching to `t3.small` to save up to 50% in compute costs.

---

## 🛠️ Architectural Recommendations
- Ensure all resources include mandatory compliance tagging (e.g. `Owner`, `Project`, `CostCenter`). Currently only basic tags are set.
- Pin provider versions strictly in your root module configurations to prevent accidental drift on future runs.
"""

        try:
            if self.provider == "gemini":
                response = self.model.generate_content(prompt)
                return response.text
            elif self.provider == "openai":
                response = self.client.chat.completions.create(
                    model=self.model_name,
                    messages=[{"role": "user", "content": prompt}]
                )
                return response.choices[0].message.content
        except Exception as e:
            logger.error(f"Error generating review from AI provider: {e}")
            return f"### 🤖 AI Review Failed\nAn error occurred while generating the plan analysis: {str(e)}"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AI Terraform Plan Reviewer")
    parser.add_argument("--plan", required=True, help="Path to Terraform Plan JSON file")
    parser.add_argument("--output", default="tf_review.md", help="Output Markdown file (default: tf_review.md)")
    args = parser.parse_args()

    reviewer = TFPlanAIReviewer()
    summary = reviewer.parse_plan(args.plan)
    
    review_md = reviewer.generate_review(summary)
    
    with open(args.output, "w") as f:
        f.write(review_md)
        
    logger.info(f"Successfully generated AI review and saved to: {args.output}")
    print("\n" + review_md)
