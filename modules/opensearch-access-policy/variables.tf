variable "collection_name" {
  description = "Name of the OpenSearch Serverless collection"
  type        = string
}

variable "lambda_role_arns" {
  description = "List of Lambda role ARNs that need access to OpenSearch"
  type        = list(string)
}
