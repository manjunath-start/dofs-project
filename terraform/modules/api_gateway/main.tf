resource "aws_api_gateway_rest_api" "dofs_api" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "DOFS Order API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "order_resource" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  parent_id   = aws_api_gateway_rest_api.dofs_api.root_resource_id
  path_part   = "order"
}

resource "aws_api_gateway_method" "order_post" {
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "order_options" {
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "order_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.api_handler_lambda_arn
}

resource "aws_api_gateway_integration" "order_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "order_post_200" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_method_response" "order_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration_response" "order_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_options.http_method
  status_code = aws_api_gateway_method_response.order_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_deployment" "dofs_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.order_post_integration,
    aws_api_gateway_integration.order_options_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.dofs_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.order_resource.id,
      aws_api_gateway_method.order_post.id,
      aws_api_gateway_method.order_options.id,
      aws_api_gateway_integration.order_post_integration.id,
      aws_api_gateway_integration.order_options_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dofs_api_stage" {
  deployment_id = aws_api_gateway_deployment.dofs_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  stage_name    = var.environment

  tags = {
    Environment = var.environment
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.dofs_api.execution_arn}/*/*"
}