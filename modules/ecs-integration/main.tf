
provider "aws" {
  region = "ap-south-1"
}


resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_step_function_policy" {
  name = "${var.project_name}-ecs-step-function-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeExecution",
          "states:DescribeStateMachine"
        ]
        Resource = var.step_function_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-pipeline-trigger"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_ecs_task_definition" "pipeline_trigger" {
  family                   = "${var.project_name}-pipeline-trigger"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "pipeline-trigger"
      image = var.container_image
      
      environment = [
        {
          name  = "STEP_FUNCTION_ARN"
          value = var.step_function_arn
        },
        {
          name  = "S3_BUCKET"
          value = var.s3_bucket_name
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = var.tags
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = var.vpc_id
}
