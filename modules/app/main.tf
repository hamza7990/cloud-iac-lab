data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/.build/${var.name}.zip"
  excludes    = ["__pycache__"]
}

resource "aws_dynamodb_table" "items" {
  name         = "${var.name}-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}

# Created here so Terraform owns it (retention, destroy). Without this
# Lambda creates the group itself and it never expires.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}-api"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name}-api-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# Least privilege: two DynamoDB actions on one table, and log writes
# to one log group. No statement uses a wildcard resource.
data "aws_iam_policy_document" "permissions" {
  statement {
    sid       = "ItemsTable"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.items.arn]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${var.name}-api-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.permissions.json
}

resource "aws_lambda_function" "api" {
  function_name    = "${var.name}-api"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  memory_size      = var.memory_size
  timeout          = var.timeout

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.items.name
      LOG_LEVEL  = var.log_level
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  depends_on = [aws_iam_role_policy.lambda]
}

# An HTTPS URL for the function, no API Gateway needed. AWS_IAM means
# callers must sign requests, so the URL is not open to the internet.
resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "AWS_IAM"
}
