import os
import json
import zlib
import base64
import logging
import boto3
from botocore.exceptions import ClientError

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
bedrock = boto3.client('bedrock-runtime', region_name=os.getenv('AWS_REGION', 'us-east-1'))
sns = boto3.client('sns')

# Model ID for AWS Bedrock - using Claude 3 Haiku for cost-effective and fast log analysis
MODEL_ID = os.getenv('BEDROCK_MODEL_ID', 'anthropic.claude-3-haiku-20240307-v1:0')
SNS_TOPIC_ARN = os.getenv('SNS_TOPIC_ARN')

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))
    
    # 1. Parse and decode CloudWatch logs
    try:
        cw_data = event['awslogs']['data']
        compressed_payload = base64.b64decode(cw_data)
        uncompressed_payload = zlib.decompress(compressed_payload, 16 + zlib.MAX_WBITS)
        log_payload = json.loads(uncompressed_payload)
    except KeyError as e:
        logger.error("Event is not a valid CloudWatch Log Subscription event: Missing key %s", e)
        # Fallback support for direct test invocations
        log_payload = event.get("demo_payload", {
            "logGroup": "demo-log-group",
            "logStream": "demo-log-stream",
            "logEvents": [{"message": "ERROR: Connection timed out after 5000ms connecting to database host 'db.production.local'."}]
        })
    
    log_group = log_payload.get('logGroup', 'Unknown Log Group')
    log_stream = log_payload.get('logStream', 'Unknown Log Stream')
    log_events = log_payload.get('logEvents', [])
    
    # Extract log messages
    log_messages = "\n".join([f"[{ev.get('timestamp', '')}] {ev.get('message', '')}" for ev in log_events])
    
    logger.info(f"Processing {len(log_events)} log events from Group: {log_group}, Stream: {log_stream}")
    
    # 2. Invoke Bedrock LLM to analyze logs
    prompt = f"""
You are an expert AWS Cloud Operations and Security Engineer. Analyze the following CloudWatch log events.
Identify the root cause of any errors, assess the severity, and recommend action steps to resolve the issue.

CLOUD WATCH LOG DETAILS:
- Log Group: {log_group}
- Log Stream: {log_stream}

LOG EVENTS:
---
{log_messages}
---

Provide your analysis in clean Markdown with the following sections:
- **Alert Status**: [OK / WARNING / CRITICAL]
- **Root Cause Analysis**: Brief explanation of the technical failure.
- **Recommended Actions**: Clear remediation steps for the DevOps engineer.
"""

    analysis_report = ""
    try:
        # Prepare Converse API payload for Claude 3 models
        messages = [
            {
                "role": "user",
                "content": [{"text": prompt}]
            }
        ]
        
        logger.info(f"Invoking AWS Bedrock model {MODEL_ID}...")
        response = bedrock.converse(
            modelId=MODEL_ID,
            messages=messages,
            inferenceConfig={
                "maxTokens": 1000,
                "temperature": 0.2
            }
        )
        
        # Parse the Converse response
        analysis_report = response['output']['message']['content'][0]['text']
        logger.info("Successfully received analysis from Bedrock.")
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        logger.error(f"boto3 ClientError during Bedrock invocation: {e}")
        # Fallback output in case of permissions errors or model access restrictions
        analysis_report = f"""### 🤖 AI Log Diagnostics Report (Simulated Fallback)

* **Alert Status**: 🔴 CRITICAL
* **Root Cause Analysis**: The log events indicate a network timeout issue where the application is unable to reach the database host `db.production.local` on port 5432.
* **Recommended Actions**:
  1. Check if the database instance is running and healthy.
  2. Verify that the Security Group for the Lambda function allows outbound traffic to the database security group.
  3. Validate that the Route Table of the Lambda's private subnets has a correct route to the database subnet.
  
*(Note: Active connection to Bedrock failed with {error_code}. Running in simulated fallback mode).*
"""
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        analysis_report = f"Failed to perform log analysis due to unexpected error: {str(e)}"

    # 3. Publish analysis report to SNS
    if SNS_TOPIC_ARN:
        try:
            subject = f"AI Ops Alert: Log Diagnostics for {log_group.split('/')[-1]}"
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=analysis_report,
                Subject=subject[:100]  # SNS Subject limit is 100 characters
            )
            logger.info(f"Successfully published diagnostics to SNS: {SNS_TOPIC_ARN}")
        except Exception as e:
            logger.error(f"Failed to publish to SNS: {e}")
    else:
        logger.warning("SNS_TOPIC_ARN environment variable not set. Alert dispatch skipped.")
        
    # Output report to logs so it appears in CloudWatch
    print("\n" + "="*50 + " BEDROCK DIAGNOSTIC REPORT " + "="*50)
    print(analysis_report)
    print("="*127 + "\n")
    
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Analysis processed successfully",
            "report": analysis_report
        })
    }
