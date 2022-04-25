provider "aws" {
  region = "us-east-1"
}



data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/python/lambda_function.zip"
}

resource "aws_lambda_function" "terraform_lambda_func" {
  filename         = "${path.module}/python/lambda_function.zip"
  function_name    = "lambda_function"
  role             = "arn:aws:iam::384941664403:role/test_Lambda_Function_Role"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = data.archive_file.zip_the_python_code.output_base64sha256

}

resource "aws_lambda_permission" "lambda_permission" {
  #depends_on = [aws_api_gateway_method.postmethod]
  statement_id = "AllowAPIInvoke"
  action       = "lambda:InvokeFunction"
  #your lambda function ARN
  #function_name = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:${aws_lambda_function.terraform_lambda_func.function_name}"
  #function_name = "helloworld_Lambda_Function"
  function_name = aws_lambda_function.terraform_lambda_func.function_name
  principal     = "apigateway.amazonaws.com"
  #source_arn = "arn:aws:execute-api:us-east-1:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/POST${aws_api_gateway_resource.proxy.path}"
  #source_arn = "arn:aws:execute-api:us-east-1:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/POST/"
  #source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*${aws_api_gateway_resource.proxy.path}"

}

resource "aws_api_gateway_rest_api" "api" {
  name        = "test_new_api_gateway"
  description = "API Gateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "TestApi"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "POST"
  authorization = "NONE"

}

resource "aws_api_gateway_integration" "lambda_test" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.terraform_lambda_func.invoke_arn
  #credentials             = "arn:aws:iam::384941664403:role/apigatewayawsproxyexecrole"
  #credentials = aws_iam_role.apigateway_role.arn
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "GET"
  authorization = "NONE"

}
resource "aws_api_gateway_integration" "lambda_get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.terraform_lambda_func.invoke_arn

}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  #triggers = {
  #  redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api.body))
  #}

  #lifecycle {
  #  create_before_destroy = true
  #}
  depends_on = [aws_api_gateway_integration.lambda_test,aws_api_gateway_method.post]

}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "abc"
}

output "invoke_arn" {
  value = "api_gateway_deployment.api_deployment.invoke.url"
}
