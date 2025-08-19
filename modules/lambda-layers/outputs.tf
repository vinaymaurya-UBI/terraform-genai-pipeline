output "layer_arn-0" {
  description = "ARN of the Lambda layer-0"
  value       = aws_lambda_layer_version.embedding_layer-0.arn
}

output "layer_arn-1" {
  description = "ARN of the Lambda layer-1"
  value       = aws_lambda_layer_version.embedding_layer-1.arn
}

output "layer_arn-2" {
  description = "ARN of the Lambda layer-2"
  value       = aws_lambda_layer_version.embedding_layer-2.arn
}
