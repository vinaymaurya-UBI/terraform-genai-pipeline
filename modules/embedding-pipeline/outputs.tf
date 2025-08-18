output "csv_processor_lambda_arn" {
  description = "ARN of the CSV processor Lambda function"
  value       = aws_lambda_function.csv_processor.arn
}

output "opensearch_indexer_lambda_arn" {
  description = "ARN of the OpenSearch indexer Lambda function"
  value       = aws_lambda_function.opensearch_indexer.arn
}

output "step_function_arn" {
  description = "ARN of the Step Function state machine"
  value       = aws_sfn_state_machine.embedding_pipeline.arn
}

output "step_function_name" {
  description = "Name of the Step Function state machine"
  value       = aws_sfn_state_machine.embedding_pipeline.name
}
