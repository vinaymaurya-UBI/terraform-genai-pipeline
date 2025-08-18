variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket containing CSV files"
  type        = string
}

variable "opensearch_collection_arn" {
  description = "ARN of the OpenSearch collection"
  type        = string
}

variable "csv_processor_lambda_arn" {
  description = "ARN of the CSV processor Lambda function"
  type        = string
  default     = ""
}

variable "opensearch_indexer_lambda_arn" {
  description = "ARN of the OpenSearch indexer Lambda function"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
