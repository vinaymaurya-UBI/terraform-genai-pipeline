terraform {
  backend "s3" {
    bucket = "testing-vinay-genai"
    key    = "cloudplatform/dev-testing"
    region = "us-west-2"
  }
  required_version = ">=1.0.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=4.31.0"
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

resource "aws_s3_bucket" "csv_bucket" {
  bucket = "${var.project_name}-csv-files-${random_string.bucket_suffix.result}"
  tags   = local.common_tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

module "lambda_layer" {
  source = "./modules/lambda-layers"

  layer_name     = "${var.project_name}-embedding-layer"
  layer_zip_path = "./lambda-layers/embedding-layer.zip"
}

module "opensearch_collection" {
  source = "./modules/opensearch-serverless"

  collection_name     = var.opensearch_collection_name
  allow_public_access = false
  tags                = local.common_tags
}

module "iam_roles" {
  source = "./modules/iam"

  project_name              = var.project_name
  region                    = var.region
  s3_bucket_arn             = aws_s3_bucket.csv_bucket.arn
  opensearch_collection_arn = module.opensearch_collection.collection_arn
  tags                      = local.common_tags

  depends_on = [
    module.opensearch_collection
  ]
}

module "opensearch_access_policy" {
  source = "./modules/opensearch-access-policy"

  collection_name   = var.opensearch_collection_name
  lambda_role_arns  = [
    module.iam_roles.csv_processor_role_arn,
    module.iam_roles.opensearch_indexer_role_arn
  ]

  depends_on = [
    module.iam_roles,
    module.opensearch_collection
  ]
}

module "embedding_pipeline" {
  source = "./modules/embedding-pipeline"

  project_name                   = var.project_name
  csv_processor_role_arn         = module.iam_roles.csv_processor_role_arn
  opensearch_indexer_role_arn    = module.iam_roles.opensearch_indexer_role_arn
  step_function_role_arn         = module.iam_roles.step_function_role_arn
  csv_processor_zip_path         = "./lambda-functions/csv-processor/csv-processor.zip"
  opensearch_indexer_zip_path    = "./lambda-functions/opensearch-indexer/opensearch-indexer.zip"
  layer_arn                      = module.lambda_layer.layer_arn
  opensearch_endpoint            = module.opensearch_collection.collection_endpoint
  tags                           = local.common_tags

  depends_on = [
    module.iam_roles,
    module.opensearch_collection,
    module.opensearch_access_policy,
    module.lambda_layer
  ]
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for CSV files"
  value       = aws_s3_bucket.csv_bucket.id
}

output "opensearch_collection_endpoint" {
  description = "OpenSearch collection endpoint"
  value       = module.opensearch_collection.collection_endpoint
}

output "step_function_arn" {
  description = "ARN of the embedding pipeline Step Function"
  value       = module.embedding_pipeline.step_function_arn
}

output "csv_processor_lambda_arn" {
  description = "ARN of the CSV processor Lambda function"
  value       = module.embedding_pipeline.csv_processor_lambda_arn
}

output "opensearch_indexer_lambda_arn" {
  description = "ARN of the OpenSearch indexer Lambda function"
  value       = module.embedding_pipeline.opensearch_indexer_lambda_arn
}
