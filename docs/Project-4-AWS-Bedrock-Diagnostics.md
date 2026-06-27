# Project 4: AWS Bedrock Log Diagnostics Agent

The **AWS Bedrock Log Diagnostics Agent** is a serverless application designed to detect and troubleshoot failures in AWS workloads. By leveraging CloudWatch Log Subscription Filters, any keyword failures (such as "ERROR" or "Exception") trigger a Lambda function that queries AWS Bedrock (Claude 3 Haiku) to diagnose the issue and alert engineers via SNS.

---

## 🏗️ Architecture Design

```
Application -> CloudWatch Log Group -> Filter Trigger -> Lambda -> Bedrock (Claude 3) -> SNS Alerts
```

---

## ⚙️ How it Works

1. **Trigger Filters**: CloudWatch Log Subscription filters watch for keyword patterns: `?ERROR ?Exception ?fail ?timeout`.
2. **Payload Decompression**: CloudWatch sends logs to Lambda encoded as base64 and compressed in gzip format. The Lambda handler decodes and decompresses the input:
   ```python
   compressed_payload = base64.b64decode(cw_data)
   uncompressed_payload = zlib.decompress(compressed_payload, 16 + zlib.MAX_WBITS)
   ```
3. **Bedrock Conversation**: The Lambda script calls the `converse` API of `boto3` Bedrock Runtime Client passing Claude 3 model instructions.
4. **Alerting**: The resulting Markdown review is pushed to an SNS Topic that routes it to email lists, OpsGenie, PagerDuty, or Slack.

---

## 🚀 How to Run & Verify

### Local Dry-Run Invocation
You can invoke the Lambda handler locally using python to test the dry-run fallback behavior:
```bash
python -c "import sys; sys.path.append('ai-bedrock-log-diagnostics/lambda'); import handler; handler.lambda_handler({}, None)"
```
*Expected Result: The terminal logs show the receipt of the mock event, fallback to dry-run, and printout of the AI database connectivity diagnostic report.*

### Deploying to AWS
1. Deploy via Terraform:
   ```bash
   cd ai-bedrock-log-diagnostics/terraform
   terraform init
   terraform apply
   ```
2. Test by writing a mock error to the CloudWatch Log Group using the AWS CLI:
   ```bash
   aws logs put-log-events \
     --log-group-name "/aws/apps/ai-bedrock-ops-application" \
     --log-stream-name "test-stream" \
     --log-events "[{\"timestamp\": $(date +%s%3N), \"message\": \"ERROR: Failed to establish handshake with db.production.local:5432\"}]"
   ```
3. Verify that the SNS Topic receives the generated Claude 3 diagnostic report.
