#!/bin/bash

# Test script for AWS Embedding Pipeline
# This script tests the deployed infrastructure with various data files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Embedding Pipeline Test Suite      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check if infrastructure is deployed
if ! terraform output > /dev/null 2>&1; then
    echo -e "${RED}Error: Terraform infrastructure not found. Please run deployment first.${NC}"
    exit 1
fi

# Get infrastructure details
S3_BUCKET=$(terraform output -raw s3_bucket_name)
STEP_FUNCTION_ARN=$(terraform output -raw step_function_arn)
OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_collection_endpoint)

echo -e "${YELLOW}Testing Infrastructure:${NC}"
echo "S3 Bucket: $S3_BUCKET"
echo "Step Function: $STEP_FUNCTION_ARN"
echo "OpenSearch: $OPENSEARCH_ENDPOINT"
echo

# Function to upload test data
upload_test_data() {
    echo -e "${YELLOW}Uploading test data files...${NC}"
    
    local files=(
        "sample-data/sample-products.csv"
        "sample-data/sample-articles.csv"
        "sample-data/large-products.csv"
        "sample-data/research-papers.csv"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            aws s3 cp "$file" s3://$S3_BUCKET/
            echo -e "${GREEN}✓ Uploaded $(basename $file)${NC}"
        else
            echo -e "${RED}✗ File not found: $file${NC}"
        fi
    done
    
    echo
    echo "S3 bucket contents:"
    aws s3 ls s3://$S3_BUCKET/
    echo
}

# Function to execute pipeline test
execute_pipeline_test() {
    local test_name=$1
    local csv_file=$2
    local columns=$3
    
    echo -e "${YELLOW}Test: $test_name${NC}"
    echo "File: $csv_file"
    echo "Columns: $columns"
    
    # Create input JSON
    local input_json=$(cat <<EOF
{
  "s3_bucket": "$S3_BUCKET",
  "csv_file_path": "$csv_file",
  "columns_to_embed": $columns
}
EOF
)
    
    echo "Input: $input_json"
    
    # Start execution
    local execution_name="test-$(echo $csv_file | sed 's/\.csv//' | sed 's/[^a-zA-Z0-9]/-/g')-$(date +%s)"
    local execution_arn=$(aws stepfunctions start-execution \
        --state-machine-arn $STEP_FUNCTION_ARN \
        --name $execution_name \
        --input "$input_json" \
        --query 'executionArn' \
        --output text)
    
    echo "Execution ARN: $execution_arn"
    
    # Monitor execution
    local start_time=$(date +%s)
    local timeout=600  # 10 minutes
    
    while true; do
        local status=$(aws stepfunctions describe-execution \
            --execution-arn $execution_arn \
            --query 'status' \
            --output text)
        
        case $status in
            "SUCCEEDED")
                echo -e "${GREEN}✓ Test passed: $test_name${NC}"
                
                # Get output
                local output=$(aws stepfunctions describe-execution \
                    --execution-arn $execution_arn \
                    --query 'output' \
                    --output text)
                echo "Result: $output"
                echo
                return 0
                ;;
            "FAILED"|"TIMED_OUT"|"ABORTED")
                echo -e "${RED}✗ Test failed: $test_name${NC}"
                echo "Status: $status"
                
                # Get error details
                local error=$(aws stepfunctions describe-execution \
                    --execution-arn $execution_arn \
                    --query 'error' \
                    --output text 2>/dev/null || echo "No error details")
                echo "Error: $error"
                echo
                return 1
                ;;
            "RUNNING")
                local current_time=$(date +%s)
                local elapsed=$((current_time - start_time))
                
                if [ $elapsed -gt $timeout ]; then
                    echo -e "${RED}✗ Test timeout: $test_name (10 minutes)${NC}"
                    echo
                    return 1
                fi
                
                echo "Status: $status (${elapsed}s elapsed)"
                sleep 15
                ;;
            *)
                echo "Unknown status: $status"
                sleep 5
                ;;
        esac
    done
}

# Function to check OpenSearch indices
check_opensearch_indices() {
    echo -e "${YELLOW}Checking OpenSearch indices...${NC}"
    
    # This is a placeholder - actual OpenSearch queries require proper authentication
    # In practice, you'd use the search-examples.py script
    echo "OpenSearch indices should be created for each CSV file:"
    echo "- sample-products"
    echo "- sample-articles"
    echo "- large-products"
    echo "- research-papers"
    echo
    echo "Use examples/search-examples.py to verify index contents"
    echo
}

# Function to check CloudWatch logs
check_logs() {
    echo -e "${YELLOW}Checking recent CloudWatch logs...${NC}"
    
    echo "CSV Processor logs (last 5 minutes):"
    aws logs filter-log-events \
        --log-group-name /aws/lambda/embedding-pipeline-csv-processor \
        --start-time $(($(date +%s) - 300))000 \
        --query 'events[?message].[timestamp,message]' \
        --output table || echo "No recent logs found"
    echo
    
    echo "OpenSearch Indexer logs (last 5 minutes):"
    aws logs filter-log-events \
        --log-group-name /aws/lambda/embedding-pipeline-opensearch-indexer \
        --start-time $(($(date +%s) - 300))000 \
        --query 'events[?message].[timestamp,message]' \
        --output table || echo "No recent logs found"
    echo
}

# Main test execution
main() {
    # Upload test data
    upload_test_data
    
    # Test cases
    local tests_passed=0
    local total_tests=4
    
    echo -e "${BLUE}Running test cases...${NC}"
    echo
    
    # Test 1: Basic products data
    if execute_pipeline_test "Basic Products" "sample-products.csv" '["title", "description"]'; then
        ((tests_passed++))
    fi
    
    # Test 2: Articles with different columns
    if execute_pipeline_test "Articles Content" "sample-articles.csv" '["title", "content"]'; then
        ((tests_passed++))
    fi
    
    # Test 3: Larger dataset
    if execute_pipeline_test "Large Products Dataset" "large-products.csv" '["title", "description", "brand"]'; then
        ((tests_passed++))
    fi
    
    # Test 4: Research papers
    if execute_pipeline_test "Research Papers" "research-papers.csv" '["title", "abstract"]'; then
        ((tests_passed++))
    fi
    
    # Check results
    check_opensearch_indices
    check_logs
    
    # Summary
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}           Test Results                 ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ $tests_passed -eq $total_tests ]; then
        echo -e "${GREEN}All tests passed! ($tests_passed/$total_tests)${NC}"
        echo -e "${GREEN}Embedding pipeline is working correctly 🎉${NC}"
    else
        echo -e "${RED}Some tests failed. ($tests_passed/$total_tests passed)${NC}"
        echo -e "${YELLOW}Check CloudWatch logs for detailed error information.${NC}"
    fi
    
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Run search examples: python3 examples/search-examples.py"
    echo "2. Monitor executions: aws stepfunctions list-executions --state-machine-arn $STEP_FUNCTION_ARN"
    echo "3. View detailed logs: aws logs tail /aws/lambda/embedding-pipeline-csv-processor --follow"
    echo
    
    if [ $tests_passed -ne $total_tests ]; then
        exit 1
    fi
}

# Run main function
main "$@"
