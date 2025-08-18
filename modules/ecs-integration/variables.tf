variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "step_function_arn" {
  description = "ARN of the Step Function to trigger"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket containing CSV files"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket containing CSV files"
  type        = string
}

variable "container_image" {
  description = "Container image for the ECS task"
  type        = string
  default     = "amazonlinux:2"
}

variable "vpc_id" {
  description = "VPC ID for ECS tasks"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
