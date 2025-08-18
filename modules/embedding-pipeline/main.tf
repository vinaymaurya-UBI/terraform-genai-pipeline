resource "aws_lambda_function" "csv_processor" {
  function_name = "${var.project_name}-csv-processor"
  role          = var.csv_processor_role_arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 900
  memory_size   = 3008

  filename         = var.csv_processor_zip_path
  source_code_hash = filebase64sha256(var.csv_processor_zip_path)

  layers = [var.layer_arn]

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tags = var.tags
}

resource "aws_lambda_function" "opensearch_indexer" {
  function_name = "${var.project_name}-opensearch-indexer"
  role          = var.opensearch_indexer_role_arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 900
  memory_size   = 1024

  filename         = var.opensearch_indexer_zip_path
  source_code_hash = filebase64sha256(var.opensearch_indexer_zip_path)

  layers = [var.layer_arn]

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = var.opensearch_endpoint
      LOG_LEVEL          = "INFO"
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "step_function_logs" {
  name              = "/aws/stepfunctions/${var.project_name}-embedding-pipeline"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_sfn_state_machine" "embedding_pipeline" {
  name     = "${var.project_name}-embedding-pipeline"
  role_arn = var.step_function_role_arn

  definition = jsonencode({
    Comment = "Embedding pipeline for CSV processing and OpenSearch indexing"
    StartAt = "ProcessCSV"
    States = {
      ProcessCSV = {
        Type     = "Task"
        Resource = aws_lambda_function.csv_processor.arn
        ResultPath = "$.embedding_result"
        Next     = "IndexToOpenSearch"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "ProcessingFailed"
          }
        ]
      }
      IndexToOpenSearch = {
        Type     = "Task"
        Resource = aws_lambda_function.opensearch_indexer.arn
        InputPath = "$.embedding_result"
        End      = true
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "IndexingFailed"
          }
        ]
      }
      ProcessingFailed = {
        Type  = "Fail"
        Cause = "CSV processing failed"
      }
      IndexingFailed = {
        Type  = "Fail"
        Cause = "OpenSearch indexing failed"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_function_logs.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tags = var.tags
}

resource "aws_lambda_permission" "allow_step_function_csv" {
  statement_id  = "AllowExecutionFromStepFunctionCSV"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_processor.function_name
  principal     = "states.amazonaws.com"
  source_arn    = aws_sfn_state_machine.embedding_pipeline.arn
}

resource "aws_lambda_permission" "allow_step_function_opensearch" {
  statement_id  = "AllowExecutionFromStepFunctionOpenSearch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.opensearch_indexer.function_name
  principal     = "states.amazonaws.com"
  source_arn    = aws_sfn_state_machine.embedding_pipeline.arn
}
