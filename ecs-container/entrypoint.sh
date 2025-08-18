#!/bin/bash

echo "Starting embedding pipeline trigger..."
echo "Step Function ARN: $STEP_FUNCTION_ARN"
echo "S3 Bucket: $S3_BUCKET"

python3 /app/pipeline_trigger.py "$@"
