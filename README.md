# AWS Embedding Pipeline

A serverless data processing pipeline that reads CSV files from S3, generates embeddings using AWS Bedrock Titan models, and indexes the data in OpenSearch Serverless for vector and keyword search capabilities.

## Architecture

```
S3 CSV Files → Step Function → Lambda 1 (CSV Processor) → Lambda 2 (OpenSearch Indexer) → OpenSearch Serverless
```

### Components

- **CSV Processor Lambda**: Reads CSV files from S3 and generates embeddings using AWS Bedrock Titan
- **OpenSearch Indexer Lambda**: Stores embeddings and metadata in OpenSearch Serverless collection
- **Step Function**: Orchestrates the pipeline workflow with error handling and retries
- **OpenSearch Serverless**: Vector search collection for storing embeddings with metadata
- **IAM Roles**: Least privilege access control for each component

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0.11
- Bash shell (for deployment scripts)
- Access to AWS Bedrock Titan embedding model

## Required AWS Permissions

Your AWS user/role needs permissions for:
- S3 (GetObject)
- Lambda (CreateFunction, InvokeFunction)
- IAM (CreateRole, AttachRolePolicy)
- Step Functions (CreateStateMachine)
- OpenSearch Serverless (CreateCollection)
- Bedrock (InvokeModel for Titan)

## Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd terraform
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Deploy Infrastructure

```bash
# Automated deployment (recommended)
chmod +x deploy-all.sh
./deploy-all.sh

# Or manual step-by-step deployment
terraform init
terraform apply
```

### 4. Test the Pipeline

The automated deployment script includes testing with sample data:

```bash
# The deploy-all.sh script automatically:
# 1. Uploads sample CSV files
# 2. Executes the pipeline
# 3. Monitors execution
# 4. Shows results

# Or test manually with your own data:
aws s3 cp your-data.csv s3://$(terraform output -raw s3_bucket_name)/

# Execute pipeline
aws stepfunctions start-execution \
  --state-machine-arn $(terraform output -raw step_function_arn) \
  --input '{
    "s3_bucket": "'$(terraform output -raw s3_bucket_name)'",
    "csv_file_path": "your-data.csv",
    "columns_to_embed": ["title", "description"]
  }'
```


### Sample Execution Input

```json
{
  "s3_bucket": "embedding-pipeline-csv-files-abc12345",
  "csv_file_path": "sample-products.csv",
  "columns_to_embed": ["title", "description"]
}
```

### Expected Output

The pipeline will:
1. Read the CSV from S3
2. Generate embeddings for combined "title" and "description" fields
3. Store in OpenSearch index named "sample-products"
4. Include metadata: `{"id": "1", "category": "Electronics", "price": "299.99"}`

## Configuration

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `child_account_id` | AWS Account ID | `"123456789012"` |
| `region` | AWS Region | `"us-west-2"` |
| `environment` | Environment name | `"dev"` |
| `project_name` | Project name for resources | `"embedding-pipeline"` |
| `opensearch_collection_name` | OpenSearch collection name | `"embedding-collection"` |

### Environment Variables

The Lambda functions use these environment variables:
- `OPENSEARCH_ENDPOINT`: Automatically set by Terraform
- `AWS_REGION`: Set by Lambda runtime
- `LOG_LEVEL`: Set to "INFO"

## Usage Examples

### Basic Pipeline Execution

```bash
# Start execution with minimal input
aws stepfunctions start-execution \
  --state-machine-arn $(terraform output -raw step_function_arn) \
  --input '{
    "s3_bucket": "your-bucket-name",
    "csv_file_path": "data/products.csv",
    "columns_to_embed": ["name", "description"]
  }'
```

### Multiple Column Embedding

```bash
# Embed multiple columns together
aws stepfunctions start-execution \
  --state-machine-arn $(terraform output -raw step_function_arn) \
  --input '{
    "s3_bucket": "your-bucket-name",
    "csv_file_path": "data/articles.csv",
    "columns_to_embed": ["title", "content", "tags"]
  }'
```

### Search Examples

After indexing, search your data:

```python
from opensearchpy import OpenSearch
import boto3
from requests_aws4auth import AWS4Auth

# Setup OpenSearch client
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, 'us-west-2', 'aoss', session_token=credentials.token)

client = OpenSearch(
    hosts=[{'host': 'your-opensearch-endpoint', 'port': 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True
)

# Vector search example
query_vector = [0.1, 0.2, ...]  # Your query embedding
search_body = {
    "query": {
        "knn": {
            "embedding": {
                "vector": query_vector,
                "k": 5
            }
        }
    }
}

response = client.search(index="sample-products", body=search_body)
```

## Monitoring

### CloudWatch Logs

- Step Function logs: `/aws/stepfunctions/embedding-pipeline-embedding-pipeline`
- CSV Processor logs: `/aws/lambda/embedding-pipeline-csv-processor`
- OpenSearch Indexer logs: `/aws/lambda/embedding-pipeline-opensearch-indexer`

### Step Function Monitoring

```bash
# List recent executions
aws stepfunctions list-executions \
  --state-machine-arn $(terraform output -raw step_function_arn)

# Get execution details
aws stepfunctions describe-execution \
  --execution-arn <execution-arn>
```

## Project Structure

```
terraform/
├── .gitignore                    # Comprehensive ignore rules
├── modules/
│   ├── opensearch-serverless/    # OpenSearch collection (basic)
│   ├── opensearch-access-policy/ # OpenSearch access management  
│   ├── embedding-pipeline/       # Step Function and Lambda functions
│   ├── lambda-layers/            # Lambda layer for dependencies
│   ├── iam/                      # IAM roles and policies
│   └── ecs-integration/          # ECS container for automation
├── lambda-functions/
│   ├── csv-processor/            # CSV reading and Bedrock embedding
│   └── opensearch-indexer/       # OpenSearch indexing
├── lambda-layers/                # Dependencies and build scripts
├── ecs-container/                # Docker container for ECS triggers
├── main.tf                       # Main Terraform configuration
├── variables.tf                  # Input variables
├── terraform.tfvars.example      # Example configuration
├── deploy-all.sh                 # Complete automated deployment
├── README.md                     # This file
```

## Troubleshooting

### Common Issues

1. **Bedrock Access Denied**
   - Ensure your AWS account has access to Bedrock Titan models
   - Check IAM permissions for `bedrock:InvokeModel`

2. **OpenSearch Index Creation Failed**
   - Verify OpenSearch collection is active
   - Check IAM permissions for OpenSearch access

3. **CSV File Not Found**
   - Ensure the file exists in the specified S3 bucket
   - Check S3 bucket permissions

4. **Lambda Timeout**
   - Large CSV files may need increased timeout
   - Consider processing in batches for files > 1000 rows

### Debug Commands

```bash
# Check Step Function execution status
aws stepfunctions describe-execution --execution-arn <arn>

# View Lambda logs
aws logs tail /aws/lambda/embedding-pipeline-csv-processor --follow

# Test Lambda function directly
aws lambda invoke \
  --function-name embedding-pipeline-csv-processor \
  --payload '{"s3_bucket":"bucket","csv_file_path":"file.csv","columns_to_embed":["col1"]}' \
  response.json
```

## Cost Optimization

- Lambda functions use ARM64 architecture for better price/performance
- OpenSearch Serverless scales automatically (pay per use)
- S3 Intelligent Tiering for cost-effective storage
- CloudWatch log retention set to 14 days

## Additional Resources

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Comprehensive step-by-step deployment guide
- **[API-ENDPOINTS.md](API-ENDPOINTS.md)** - Complete API usage documentation with examples
- **[examples/](examples/)** - Usage examples and search scripts
- **[sample-data/](sample-data/)** - Sample CSV files for testing

## Available Scripts

- **`deploy-all.sh`** - Complete automated deployment with testing
- **`test-deployment.sh`** - Comprehensive test suite with multiple data files
- **`examples/execute-pipeline.sh`** - Execute pipeline with sample data
- **`examples/search-examples.py`** - Python examples for searching indexed data

## Security

- All IAM roles follow least privilege principle
- OpenSearch collection uses encryption at rest
- Lambda functions run in isolated execution environments
- No public access to OpenSearch collection
- Separate access policy module for better security management

