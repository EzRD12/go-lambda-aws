 terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.16.0"
    }
  }
}

variable "profile" {
  default = "dev"
}

provider "aws" {
  region = var.availability_zone
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda" 

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "apigateway.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "archive_file" "lambda_file" {
  type        = "zip"
  source_file = "../publish/lambda_function"
  output_path = "../publish/function.zip"
}

resource "aws_cloudwatch_log_group" "test_lambda_log_group" {
  name = "TestLambda-LogGroup"
  retention_in_days = 5
  tags = {
    Environment = "dev"
    Application = "Test lambda"
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_lambda_function" "test_lambda" {
  function_name = "test_lambda"
  handler       = "lambda_function"
  memory_size   = 128
  timeout       = 18
  runtime       = "go1.x"
  role          = aws_iam_role.iam_for_lambda.arn
  filename      = data.archive_file.lambda_file.output_path
  source_code_hash = data.archive_file.lambda_file.output_base64sha256
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.test_lambda_log_group,
  ]
}

resource "aws_lambda_permission" "allow_api" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_rest_api" "lambda_api_gateway" {
  name = "test-lambda-rest-api"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "apigat_resource_1" {
  parent_id   = aws_api_gateway_rest_api.lambda_api_gateway.root_resource_id
  path_part   = "lambda"
  rest_api_id = aws_api_gateway_rest_api.lambda_api_gateway.id
}

resource "aws_api_gateway_method" "post" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.apigat_resource_1.id
  rest_api_id   = aws_api_gateway_rest_api.lambda_api_gateway.id
}

resource "aws_api_gateway_integration" "aws_api_gateway_lambda_integration" {
  http_method = aws_api_gateway_method.post.http_method
  resource_id = aws_api_gateway_resource.apigat_resource_1.id
  rest_api_id = aws_api_gateway_rest_api.lambda_api_gateway.id
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri = aws_lambda_function.test_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api_gateway.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.lambda_api_gateway.body
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.aws_api_gateway_lambda_integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "gateway_stage" {
  deployment_id = aws_api_gateway_deployment.gateway_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.lambda_api_gateway.id
  stage_name    = var.profile
}

output "invoke_arn" {
  value = aws_api_gateway_deployment.gateway_deployment.invoke_url
}
  
output "stage_path" {
  value = aws_api_gateway_stage.gateway_stage.stage_name
}

output "stage_part" {
  value = aws_api_gateway_resource.apigat_resource_1.path_part
}

output "complete_invoke_url" {
  value = "${aws_api_gateway_deployment.gateway_deployment.invoke_url}/${aws_api_gateway_stage.gateway_stage.stage_name}/${aws_api_gateway_resource.apigat_resource_1.path_part}"
}