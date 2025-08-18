variable "collection_name" {
  description = "Name of the OpenSearch Serverless collection"
  type        = string
}

variable "allow_public_access" {
  description = "Allow public access to the collection"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
