#!/bin/bash

# Complete deployment script for AWS Embedding Pipeline
# This script automates the entire deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AWS Embedding Pipeline Deployment    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not found. Please install AWS CLI.${NC}"
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform not found. Please install Terraform >= 1.0.11.${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured. Run 'aws configure'.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Creating terraform.tfvars from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${RED}Please edit terraform.tfvars with your AWS account details before continuing.${NC}"
    echo "Press Enter when ready to continue..."
    read
fi

# Step 1: Build Lambda layer
echo -e "${YELLOW}Step 1: Building Lambda layer...${NC}"
cd lambda-layers
if [ ! -f "build_layer.sh" ]; then
    echo -e "${RED}Error: build_layer.sh not found${NC}"
    exit 1
fi
chmod +x build_layer.sh
./build_layer.sh
cd ..
echo -e "${GREEN}✓ Lambda layer built successfully${NC}"
echo

# Step 2: Package Lambda functions
echo -e "${YELLOW}Step 2: Packaging Lambda functions...${NC}"

# Package CSV processor
cd lambda-functions/csv-processor
chmod +x package.sh
./package.sh
echo -e "${GREEN}✓ CSV processor packaged${NC}"

# Package OpenSearch indexer
cd ../opensearch-indexer
chmod +x package.sh
./package.sh
echo -e "${GREEN}✓ OpenSearch indexer packaged${NC}"
cd ../..
echo

# Step 3: Deploy infrastructure
echo -e "${YELLOW}Step 3: Deploying infrastructure...${NC}"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Plan deployment
echo "Planning deployment..."
terraform plan -out=tfplan

# Apply deployment
echo "Applying deployment..."
terraform apply tfplan

echo -e "${GREEN}✓ Infrastructure deployed successfully${NC}"
echo

# Step 4: Upload sample data
echo -e "${YELLOW}Step 4: Uploading sample data...${NC}"

# Get S3 bucket name from Terraform output
S3_BUCKET=$(terraform output -raw s3_bucket_name)
echo "S3 Bucket: $S3_BUCKET"

# Upload sample files
if [ -f "sample-data/sample-products.csv" ]; then
    aws s3 cp sample-data/sample-products.csv s3://$S3_BUCKET/
    echo -e "${GREEN}✓ Uploaded sample-products.csv${NC}"
else
    echo -e "${RED}Warning: sample-data/sample-products.csv not found${NC}"
fi

if [ -f "sample-data/sample-articles.csv" ]; then
    aws s3 cp sample-data/sample-articles.csv s3://$S3_BUCKET/
    echo -e "${GREEN}✓ Uploaded sample-articles.csv${NC}"
else
    echo -e "${RED}Warning: sample-data/sample-articles.csv not found${NC}"
fi

# Verify uploads
echo "Verifying S3 uploads..."
aws s3 ls s3://$S3_BUCKET/
echo

# Step 5: Test the pipeline
echo -e "${YELLOW}Step 5: Testing the pipeline...${NC}"

STEP_FUNCTION_ARN=$(terraform output -raw step_function_arn)
echo "Step Function ARN: $STEP_FUNCTION_ARN"

# Test with products data
echo "Testing with products data..."
EXECUTION_ARN=$(aws stepfunctions start-execution \
  --state-machine-arn $STEP_FUNCTION_ARN \
  --name "test-products-$(date +%s)" \
  --input '{
    "s3_bucket": "'$S3_BUCKET'",
    "csv_file_path": "sample-products.csv",
    "columns_to_embed": ["title", "description"]
  }' \
  --query 'executionArn' \
  --output text)

echo "Execution started: $EXECUTION_ARN"

# Monitor execution
echo "Monitoring execution (timeout: 5 minutes)..."
START_TIME=$(date +%s)
TIMEOUT=300  # 5 minutes

while true; do
    STATUS=$(aws stepfunctions describe-execution \
      --execution-arn $EXECUTION_ARN \
      --query 'status' \
      --output text)
    
    echo "Status: $STATUS"
    
    case $STATUS in
        "SUCCEEDED")
            echo -e "${GREEN}✓ Pipeline test completed successfully!${NC}"
            
            # Get output
            OUTPUT=$(aws stepfunctions describe-execution \
              --execution-arn $EXECUTION_ARN \
              --query 'output' \
              --output text)
            echo "Output: $OUTPUT"
            break
            ;;
        "FAILED"|"TIMED_OUT"|"ABORTED")
            echo -e "${RED}✗ Pipeline test failed with status: $STATUS${NC}"
            
            # Get error details
            ERROR=$(aws stepfunctions describe-execution \
              --execution-arn $EXECUTION_ARN \
              --query 'error' \
              --output text 2>/dev/null || echo "No error details")
            echo "Error: $ERROR"
            exit 1
            ;;
        "RUNNING")
            CURRENT_TIME=$(date +%s)
            ELAPSED=$((CURRENT_TIME - START_TIME))
            
            if [ $ELAPSED -gt $TIMEOUT ]; then
                echo -e "${RED}✗ Test timeout reached (5 minutes)${NC}"
                exit 1
            fi
            
            echo "Execution in progress... waiting 10 seconds"
            sleep 10
            ;;
        *)
            echo "Unknown status: $STATUS"
            sleep 5
            ;;
    esac
done

echo

# Step 6: Display results
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}       Deployment Completed!           ${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${YELLOW}Infrastructure Details:${NC}"
echo "S3 Bucket: $(terraform output -raw s3_bucket_name)"
echo "Step Function ARN: $(terraform output -raw step_function_arn)"
echo "OpenSearch Endpoint: $(terraform output -raw opensearch_collection_endpoint)"
echo "CSV Processor Lambda: $(terraform output -raw csv_processor_lambda_arn)"
echo "OpenSearch Indexer Lambda: $(terraform output -raw opensearch_indexer_lambda_arn)"
echo

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test with your own CSV files:"
echo "   aws s3 cp your-file.csv s3://$(terraform output -raw s3_bucket_name)/"
echo
echo "2. Execute pipeline:"
echo "   aws stepfunctions start-execution \\"
echo "     --state-machine-arn $(terraform output -raw step_function_arn) \\"
echo "     --input '{\"s3_bucket\":\"$(terraform output -raw s3_bucket_name)\",\"csv_file_path\":\"your-file.csv\",\"columns_to_embed\":[\"col1\",\"col2\"]}'"
echo
echo "3. Search your data using examples/search-examples.py"
echo
echo "4. Monitor executions:"
echo "   aws stepfunctions list-executions --state-machine-arn $(terraform output -raw step_function_arn)"
echo
echo "5. View CloudWatch logs:"
echo "   aws logs tail /aws/lambda/embedding-pipeline-csv-processor --follow"
echo

echo -e "${YELLOW}Useful Commands:${NC}"
echo "# Run automated test:"
echo "./examples/execute-pipeline.sh"
echo
echo "# Clean up everything:"
echo "terraform destroy"
echo

echo -e "${GREEN}Deployment completed successfully! 🎉${NC}"
