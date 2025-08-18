#!/usr/bin/env python3

import boto3
import json
import os
import sys
import time
from datetime import datetime

def trigger_step_function(step_function_arn, input_data, execution_name=None):
    """Trigger Step Function execution"""
    client = boto3.client('stepfunctions')
    
    if not execution_name:
        execution_name = f"ecs-trigger-{int(time.time())}"
    
    try:
        response = client.start_execution(
            stateMachineArn=step_function_arn,
            name=execution_name,
            input=json.dumps(input_data)
        )
        
        execution_arn = response['executionArn']
        print(f"Started execution: {execution_arn}")
        
        return execution_arn
        
    except Exception as e:
        print(f"Error starting execution: {e}")
        raise

def monitor_execution(execution_arn, timeout_minutes=30):
    """Monitor Step Function execution until completion"""
    client = boto3.client('stepfunctions')
    
    start_time = time.time()
    timeout_seconds = timeout_minutes * 60
    
    while True:
        try:
            response = client.describe_execution(executionArn=execution_arn)
            status = response['status']
            
            print(f"Execution status: {status}")
            
            if status == 'SUCCEEDED':
                print("Execution completed successfully!")
                output = response.get('output')
                if output:
                    print(f"Output: {output}")
                return True
                
            elif status in ['FAILED', 'TIMED_OUT', 'ABORTED']:
                print(f"Execution failed with status: {status}")
                if 'error' in response:
                    print(f"Error: {response['error']}")
                if 'cause' in response:
                    print(f"Cause: {response['cause']}")
                return False
                
            elif status == 'RUNNING':
                elapsed = time.time() - start_time
                if elapsed > timeout_seconds:
                    print(f"Timeout reached ({timeout_minutes} minutes)")
                    return False
                    
                print("Execution in progress... waiting 30 seconds")
                time.sleep(30)
                
        except Exception as e:
            print(f"Error monitoring execution: {e}")
            return False

def list_s3_csv_files(bucket_name, prefix=""):
    """List CSV files in S3 bucket"""
    s3 = boto3.client('s3')
    
    try:
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name, Prefix=prefix)
        
        csv_files = []
        for page in pages:
            if 'Contents' in page:
                for obj in page['Contents']:
                    key = obj['Key']
                    if key.lower().endswith('.csv'):
                        csv_files.append(key)
        
        return csv_files
        
    except Exception as e:
        print(f"Error listing S3 files: {e}")
        return []

def main():
    """Main function to trigger embedding pipeline"""
    
    # Get environment variables
    step_function_arn = os.environ.get('STEP_FUNCTION_ARN')
    s3_bucket = os.environ.get('S3_BUCKET')
    
    if not step_function_arn or not s3_bucket:
        print("Error: STEP_FUNCTION_ARN and S3_BUCKET environment variables required")
        sys.exit(1)
    
    # Get command line arguments or use defaults
    if len(sys.argv) > 1:
        csv_file_path = sys.argv[1]
        columns_to_embed = sys.argv[2:] if len(sys.argv) > 2 else ["title", "description"]
    else:
        # Auto-discover CSV files
        print(f"Scanning S3 bucket {s3_bucket} for CSV files...")
        csv_files = list_s3_csv_files(s3_bucket)
        
        if not csv_files:
            print("No CSV files found in bucket")
            sys.exit(1)
            
        print(f"Found CSV files: {csv_files}")
        csv_file_path = csv_files[0]  # Process first CSV file
        columns_to_embed = ["title", "description"]  # Default columns
    
    print(f"Processing file: {csv_file_path}")
    print(f"Columns to embed: {columns_to_embed}")
    
    # Prepare Step Function input
    input_data = {
        "s3_bucket": s3_bucket,
        "csv_file_path": csv_file_path,
        "columns_to_embed": columns_to_embed
    }
    
    print(f"Step Function input: {json.dumps(input_data, indent=2)}")
    
    # Trigger Step Function
    execution_name = f"ecs-{csv_file_path.replace('/', '-').replace('.csv', '')}-{int(time.time())}"
    execution_arn = trigger_step_function(step_function_arn, input_data, execution_name)
    
    # Monitor execution
    success = monitor_execution(execution_arn)
    
    if success:
        print("Pipeline completed successfully!")
        sys.exit(0)
    else:
        print("Pipeline failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
