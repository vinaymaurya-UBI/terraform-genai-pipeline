output "csv_processor_role_arn" {
  description = "ARN of the CSV processor Lambda role"
  value       = aws_iam_role.csv_processor_role.arn
}

output "opensearch_indexer_role_arn" {
  description = "ARN of the OpenSearch indexer Lambda role"
  value       = aws_iam_role.opensearch_indexer_role.arn
}

output "step_function_role_arn" {
  description = "ARN of the Step Function role"
  value       = aws_iam_role.step_function_role.arn
}
