import os
import sys
import json
import logging
import argparse
from typing import Dict, Any, List, Optional
from kubernetes import client, config
from kubernetes.client.rest import ApiException

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("k8s-ai-analyzer")

class AIClient:
    """Wrapper to support both Google Gemini and OpenAI APIs for analysis."""
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

    def analyze_log(self, pod_name: str, logs: str, events: str) -> Dict[str, Any]:
        prompt = f"""
You are an expert Kubernetes and DevOps Engineer. Analyze the following logs and events of a failing Kubernetes Pod: '{pod_name}'.

POD LOGS (LAST 100 LINES):
---
{logs}
---

POD EVENTS / STATUS DETAILS:
---
{events}
---

Provide your analysis in EXACTLY the following JSON format:
{{
  "error_summary": "Short 1-sentence summary of the main error",
  "severity": "LOW" | "MEDIUM" | "HIGH" | "CRITICAL",
  "root_cause": "Detailed technical explanation of what caused the failure",
  "remediation_steps": [
    "Step 1: Description of what to modify or fix",
    "Step 2: Next steps..."
  ],
  "recommended_commands": [
    "kubectl command to debug or apply fix",
    "another kubectl command..."
  ]
}}
Do not include any markdown backticks, explanations, or text outside of the JSON object.
"""
        if self.provider == "dry-run":
            # Return a realistic simulated JSON response for demo purposes
            return {
                "error_summary": "Application crashed due to missing database connection environment variable.",
                "severity": "HIGH",
                "root_cause": "The application is trying to load database credentials from the 'DB_HOST' environment variable, which is not defined in the deployment spec. This led to a NullPointerException during startup, triggering a CrashLoopBackOff.",
                "remediation_steps": [
                    "Update the Deployment manifest to include the 'DB_HOST' environment variable under spec.template.spec.containers[0].env.",
                    "Ensure a Kubernetes Secret or ConfigMap exists containing the database connection details.",
                    "Apply the updated Deployment configuration using kubectl."
                ],
                "recommended_commands": [
                    "kubectl get deployment -n default",
                    "kubectl edit deployment " + pod_name.split("-")[0] + " -n default",
                    "kubectl describe configmap db-config -n default"
                ]
            }

        try:
            if self.provider == "gemini":
                response = self.model.generate_content(
                    prompt,
                    generation_config={"response_mime_type": "application/json"}
                )
                return json.loads(response.text)
            elif self.provider == "openai":
                response = self.client.chat.completions.create(
                    model=self.model_name,
                    messages=[{"role": "user", "content": prompt}],
                    response_format={"type": "json_object"}
                )
                return json.loads(response.choices[0].message.content)
        except Exception as e:
            logger.error(f"Error communicating with AI Provider: {e}")
            return {
                "error_summary": f"Failed to analyze due to API Error: {str(e)}",
                "severity": "MEDIUM",
                "root_cause": "The analyzer failed to fetch suggestions from the LLM provider.",
                "remediation_steps": ["Check API credentials", "Ensure network connectivity to the LLM API"],
                "recommended_commands": []
            }

def get_k8s_client():
    """Load cluster configuration."""
    try:
        config.load_in_cluster_config()
        logger.info("Loaded in-cluster Kubernetes configuration.")
    except config.ConfigException:
        try:
            config.load_kube_config()
            logger.info("Loaded local kubeconfig.")
        except Exception as e:
            logger.error(f"Could not configure Kubernetes client: {e}")
            sys.exit(1)
    return client.CoreV1Api()

def analyze_cluster(namespace: str, ai_client: AIClient):
    """Scan namespace for failing pods and analyze them."""
    v1 = get_k8s_client()
    logger.info(f"Scanning namespace: {namespace} for failing pods...")
    
    try:
        pods = v1.list_namespaced_pod(namespace)
    except ApiException as e:
        logger.error(f"Failed to list pods: {e}")
        return

    failing_pods = []
    for pod in pods.items:
        name = pod.metadata.name
        phase = pod.status.phase
        
        # Check container statuses for issues
        has_issue = False
        status_text = ""
        
        if phase != "Running" and phase != "Succeeded":
            has_issue = True
            status_text = f"Phase: {phase}"
        
        if pod.status.container_statuses:
            for c_status in pod.status.container_statuses:
                state = c_status.state
                if state.waiting and state.waiting.reason in ["CrashLoopBackOff", "ImagePullBackOff", "CreateContainerConfigError", "ErrImagePull"]:
                    has_issue = True
                    status_text = f"Waiting Reason: {state.waiting.reason} (Message: {state.waiting.message})"
                    break
                elif state.terminated and state.terminated.exit_code != 0:
                    has_issue = True
                    status_text = f"Terminated ExitCode: {state.terminated.exit_code} (Reason: {state.terminated.reason})"
                    break

        if has_issue:
            failing_pods.append((name, status_text))

    if not failing_pods:
        logger.info("All pods are healthy. No issues detected!")
        return

    logger.info(f"Found {len(failing_pods)} failing pod(s). Starting AI diagnostic review...")
    
    for pod_name, status_desc in failing_pods:
        print("\n" + "="*80)
        print(f"DIAGNOSTIC REPORT FOR POD: {pod_name}")
        print(f"Detected Issue: {status_desc}")
        print("="*80)
        
        # Fetch Logs
        logs = ""
        try:
            logs = v1.read_namespaced_pod_log(name=pod_name, namespace=namespace, tail_lines=100)
        except ApiException as e:
            logs = f"Error reading logs: {e.reason} ({e.status})"
            logger.warning(f"Could not retrieve logs for {pod_name}: {e.reason}")
        
        # Fetch events for this pod
        events_list = []
        try:
            field_selector = f"involvedObject.name={pod_name},involvedObject.kind=Pod"
            events = v1.list_namespaced_event(namespace, field_selector=field_selector)
            for event in events.items:
                events_list.append(f"Type: {event.type} | Reason: {event.reason} | Message: {event.message}")
        except ApiException as e:
            events_list.append(f"Error reading events: {e.reason}")
            
        events_str = "\n".join(events_list[-15:])  # Last 15 events
        
        # Run AI analysis
        analysis = ai_client.analyze_log(pod_name, logs, events_str)
        
        # Print results beautifully
        print(f"\n[AI Evaluation] Severity: {analysis.get('severity', 'UNKNOWN')}")
        print(f"Summary: {analysis.get('error_summary', 'N/A')}")
        print(f"\nRoot Cause:\n{analysis.get('root_cause', 'N/A')}")
        
        print("\nRemediation Steps:")
        for idx, step in enumerate(analysis.get('remediation_steps', []), 1):
            print(f"  {idx}. {step}")
            
        print("\nRecommended Commands:")
        for cmd in analysis.get('recommended_commands', []):
            print(f"  $ {cmd}")
        print("="*80 + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Kubernetes Pod Log AI Analyzer")
    parser.add_argument("--namespace", default="default", help="Kubernetes namespace to scan (default: default)")
    args = parser.parse_args()

    ai = AIClient()
    analyze_cluster(args.namespace, ai)
