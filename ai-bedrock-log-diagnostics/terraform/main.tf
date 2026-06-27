terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==========================================
# DIAGNOSTICS SNS TOPIC
# ==========================================
resource "aws_sns_topic" "ai_ops_alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# IAM ROLE FOR LAMBDA
# ==========================================
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Standard Lambda Logging permissions
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Custom policy for Bedrock Invocation and SNS Publishing
resource "aws_iam_policy" "lambda_custom_policy" {
  name        = "${var.project_name}-lambda-policy"
  description = "Permissions for Lambda to invoke Bedrock models and publish to SNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:*:*:foundation-model/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.ai_ops_alerts.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_custom" {
  policy_arn = aws_iam_policy.lambda_custom_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# ==========================================
# LAMBDA DEPLOYMENT PACKAGE
# ==========================================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/lambda_function.zip"
}

# ==========================================
# LAMBDA FUNCTION
# ==========================================
resource "aws_lambda_function" "bedrock_diagnostics" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-diagnostics"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30 # Analysis can take a few seconds
  memory_size      = 256

  environment {
    variables = {
      SNS_TOPIC_ARN    = aws_sns_topic.ai_ops_alerts.arn
      BEDROCK_MODEL_ID = var.bedrock_model_id
    }
  }

  tags = {
    Environment = var.environment
  }
}

# Permission for CloudWatch to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bedrock_diagnostics.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.monitored_app.arn}:*"
}

# ==========================================
# MONITORED LOG GROUP & SUBSCRIPTION FILTER
# ==========================================
resource "aws_cloudwatch_log_group" "monitored_app" {
  name              = "/aws/apps/${var.project_name}-application"
  retention_in_days = 7

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_subscription_filter" "error_trigger" {
  name            = "${var.project_name}-error-subscription"
  log_group_name  = aws_cloudwatch_log_group.monitored_app.name
  filter_pattern  = "?ERROR ?Exception ?fail ?timeout" # Matches any of these keywords
  destination_arn = aws_lambda_function.bedrock_diagnostics.arn

  depends_on = [aws_lambda_permission.allow_cloudwatch]
}
