output "function_name" {
  value = aws_lambda_function.api.function_name
}

output "function_url" {
  value = aws_lambda_function_url.api.function_url
}

output "table_name" {
  value = aws_dynamodb_table.items.name
}

output "role_arn" {
  value = aws_iam_role.lambda.arn
}

output "log_group" {
  value = aws_cloudwatch_log_group.lambda.name
}
