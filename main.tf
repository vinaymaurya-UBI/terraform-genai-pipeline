terraform {
  backend "s3" {
    bucket = "testing-opensearch-vinay"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.31.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.1.0"
    }
  }
}

provider "aws" {
  allowed_account_ids = [var.child_account_id]
  region              = var.region
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "csv_bucket" {
  bucket = "${var.project_name}-csv-files-${random_string.bucket_suffix.result}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "csv_bucket_pab" {
  bucket = aws_s3_bucket.csv_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Basic OpenSearch Serverless Collection (simplified version)
resource "aws_opensearchserverless_collection" "embedding_collection" {
  name = var.opensearch_collection_name
  type = "VECTORSEARCH"
  depends_on = [aws_opensearchserverless_security_policy.embedding_encryption]

  tags = local.common_tags
}

# OpenSearch security policy
resource "aws_opensearchserverless_security_policy" "embedding_encryption" {
  name        = "${var.opensearch_collection_name}-encryption"
  type        = "encryption"
  description = "Encryption policy for ${var.opensearch_collection_name}"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/${var.opensearch_collection_name}"
        ]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "embedding_network" {
  name        = "${var.opensearch_collection_name}-network"
  type        = "network"
  description = "Network policy for ${var.opensearch_collection_name}"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource = [
            "collection/${var.opensearch_collection_name}"
          ]
          ResourceType = "collection"
        },
        {
          Resource = [
            "collection/${var.opensearch_collection_name}"
          ]
          ResourceType = "dashboard"
        }
      ]
      AllowFromPublic = true
    }
  ])
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for CSV files"
  value       = aws_s3_bucket.csv_bucket.id
}

output "opensearch_collection_endpoint" {
  description = "OpenSearch collection endpoint"
  value       = aws_opensearchserverless_collection.embedding_collection.collection_endpoint
}

output "opensearch_collection_arn" {
  description = "ARN of the OpenSearch collection"
  value       = aws_opensearchserverless_collection.embedding_collection.arn
}
