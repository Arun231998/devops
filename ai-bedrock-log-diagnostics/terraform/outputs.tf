output "lambda_function_name" {
  value       = aws_lambda_function.bedrock_diagnostics.function_name
  description = "The name of the log diagnostics Lambda function"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.ai_ops_alerts.arn
  description = "The ARN of the SNS Topic publishing AI alert reports"
}

output "monitored_log_group_name" {
  value       = aws_cloudwatch_log_group.monitored_app.name
  description = "The name of the CloudWatch Log Group being monitored"
}
