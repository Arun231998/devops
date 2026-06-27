# Project 1: AI-Powered Kubernetes Log Analyzer

The **AI-Powered Kubernetes Log Analyzer** is a monitoring agent designed to run as a CronJob inside a Kubernetes cluster. It polls container states, identifies application crashes, retrieves runtime logs and events, and sends them to an LLM to generate troubleshooting instructions.

---

## 🏗️ Architecture Design

```
+--------------------------------------------------------+
|                   Kubernetes Cluster                   |
|                                                        |
|  +--------------------+      +----------------------+  |
|  | Failing App Pod    |      | Log Analyzer CronJob |  |
|  | (e.g. CrashLoop)   |      | (Runs every 5 min)   |  |
|  +---------+----------+      +----------+-----------+  |
|            |                            |              |
|            | Read Logs & Events         |              |
|            +----------------------------+              |
|                                         |              |
+-----------------------------------------v--------------+
                                          |
                                          | Send context to API
                                   +------v------+
                                   | Gemini /    |
                                   | OpenAI API  |
                                   +------+------+
                                          |
                                          | Returns Structured JSON
                                   +------v------+
                                   | Diagnostics |
                                   | & Cmd Fixes |
                                   +-------------+
```

---

## 🔒 RBAC Configuration
To query pods and events, the analyzer requires access to the Kubernetes API. The following permissions are provisioned in [k8s-manifests.yaml](../ai-k8s-log-analyzer/k8s-manifests.yaml):

- **ClusterRole / Role Rules**:
  - `pods`: `["get", "list", "watch"]` (Required to scan pod statuses).
  - `pods/log`: `["get", "list", "watch"]` (Required to read stdout/stderr logs).
  - `events`: `["get", "list", "watch"]` (Required to query lifecycle event codes like OOMKilled, FailedScheduling, etc.).

---

## 🚀 How to Run & Verify

### Local Dry-Run Mode
If you do not have a Kubernetes cluster running, you can run the script using mock payloads:
1. Ensure dependencies are installed:
   ```bash
   pip install -r ai-k8s-log-analyzer/requirements.txt
   ```
2. Execute the python script:
   ```bash
   python ai-k8s-log-analyzer/main.py --namespace default
   ```
   *Expected Result: The script will output a mock diagnostic report detailing simulated container crashes.*

### Deployment to Kubernetes
To deploy the analyzer:
1. Create the credentials secret inside your namespace:
   ```bash
   kubectl create secret generic ai-credentials \
     --from-literal=gemini-api-key="YOUR_GEMINI_KEY" \
     --from-literal=openai-api-key="YOUR_OPENAI_KEY"
   ```
2. Apply the manifests:
   ```bash
   kubectl apply -f ai-k8s-log-analyzer/k8s-manifests.yaml
   ```
3. Trigger the CronJob manually to verify execution:
   ```bash
   kubectl create job --from=cronjob/ai-log-analyzer manual-analyzer-run
   kubectl logs -f job/manual-analyzer-run
   ```
