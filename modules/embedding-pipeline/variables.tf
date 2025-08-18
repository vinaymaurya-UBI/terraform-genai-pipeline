variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "csv_processor_role_arn" {
  description = "ARN of the IAM role for CSV processor Lambda"
  type        = string
}

variable "opensearch_indexer_role_arn" {
  description = "ARN of the IAM role for OpenSearch indexer Lambda"
  type        = string
}

variable "step_function_role_arn" {
  description = "ARN of the IAM role for Step Function"
  type        = string
}

variable "csv_processor_zip_path" {
  description = "Path to the CSV processor Lambda zip file"
  type        = string
}

variable "opensearch_indexer_zip_path" {
  description = "Path to the OpenSearch indexer Lambda zip file"
  type        = string
}

variable "layer_arn" {
  description = "ARN of the Lambda layer"
  type        = string
}

variable "opensearch_endpoint" {
  description = "OpenSearch collection endpoint"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
