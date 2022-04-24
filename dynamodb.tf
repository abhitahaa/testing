
# Create dynamo db table
resource "aws_dynamodb_table" "example" {
  name         = "example"
  hash_key     = "id"
  range_key    = "range"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "range"
    type = "S"
  }
}

#Step 2 -  Create an IAM policy and role for the execution
#In this step, we will create an IAM policy and role which can be assumed by any API gateway. The policy attached to the role will give access to the API Gateway to perform operations on the Dynamodb table defined above.

# The policy document to access the role
data "aws_iam_policy_document" "dynamodb_table_policy_example" {
  depends_on = [aws_dynamodb_table.example]
  statement {
    sid = "dynamodbtablepolicy"

    actions = [
      "dynamodb:Query"
    ]

    resources = [
      aws_dynamodb_table.example.arn,
    ]
  }
}

# The IAM Role for the execution
resource "aws_iam_role" "api_gateway_dynamodb_example" {
  name               = "api_gateway_dynamodb_example"
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "apigateway.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": "iamroletrustpolicy"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "example_policy" {
  name = "example_policy"
  role = aws_iam_role.api_gateway_dynamodb_example.id
  policy = data.aws_iam_policy_document.dynamodb_table_policy_example.json
}

#Step 3 - Create an API Gateway
#<Code code={resource "aws_api_gateway_rest_api" "exampleApi" {   name        = "exampleApi"   description = "Example API" }}/>

#Step 4 -  Create a Resource in API Gateway
#To create routes in API Gateway, we need to create a resource and attach it to API Gateway. In the following code, the path is created as {val}. This allows us to create a parameterised route so we can execute anything like {API Gateway Route}/test. Here value test will be assigned to val keyword and we can later use it.

# API Gateway for dynamodb
resource "aws_api_gateway_rest_api" "exampleApi" {
  name        = "exampleApi"
  description = "Example API"
}

# Create a resource
resource "aws_api_gateway_resource" "resource-example" {
  rest_api_id = aws_api_gateway_rest_api.exampleApi.id
  parent_id   = aws_api_gateway_rest_api.exampleApi.root_resource_id
  path_part   = "{val}"
}
#Step 5 - Create a Method
#We will create a GET method under the resource we created above. This will allow us to make a GET request on the resource and fire off the integration attached with it.

# Create a Method
resource "aws_api_gateway_method" "get-example-method" {
  rest_api_id   = aws_api_gateway_rest_api.exampleApi.id
  resource_id   = aws_api_gateway_resource.resource-example.id
  http_method   = "GET"
  authorization = "NONE"
}

#Step 6 - Creating a Request Integration
#This is the step that will link our API Gateway with our Dynamodb. Request integration will route any request coming to the 
#defined resource and method to the integration service. The most widely used integration is Lambda but in our case, 
#we are going to use an AWS service integration with Dynamodb.

# Create an integration with the dynamo db
resource "aws_api_gateway_integration" "get-example-integration" {
  rest_api_id             = aws_api_gateway_rest_api.exampleApi.id
  resource_id             = aws_api_gateway_resource.resource-example.id
  http_method             = aws_api_gateway_method.get-example-method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:us-east-1:dynamodb:action/Query"
  credentials             = aws_iam_role.api_gateway_dynamodb_example.arn
  request_templates = {
    "application/json" = <<EOF
      {
        "TableName": "${aws_dynamodb_table.example.name}",
        "KeyConditionExpression": "id = :val",
        "ExpressionAttributeValues": {
          ":val": {
              "S": "$input.params('val')"
          }
        }
      }
    EOF
  }
}

#In the request template, we are requesting the Dynamodb table and our condition is to query where our hash_key i.e. id is equal to the val (which we set up in parameterized route).
#We have to define the table name and aws_region to make it work. You can use terraform vars or referencing by adding a $ sign in front of it. Please see the example script mentioned above to see the working copy.

#Step 7 - Creating a Response Code and template for the request.
#We have created a request and now we need to create a response mapping so it can transform and return the response to us.

#Add a response code with the method
resource "aws_api_gateway_method_response" "get-example-response-200" {
  rest_api_id = aws_api_gateway_rest_api.exampleApi.id
  resource_id = aws_api_gateway_resource.resource-example.id
  http_method = aws_api_gateway_method.get-example-method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Create a response template for dynamo db structure
resource "aws_api_gateway_integration_response" "get-example-response" {
  depends_on  = [aws_api_gateway_integration.get-example-integration]
  rest_api_id = aws_api_gateway_rest_api.exampleApi.id
  resource_id = aws_api_gateway_resource.resource-example.id
  http_method = aws_api_gateway_method.get-example-method.http_method
  status_code = aws_api_gateway_method_response.get-example-response-200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  response_templates = {
    "application/json" = <<EOF
      #set($inputRoot = $input.path('$'))
      {
        #foreach($elem in $inputRoot.Items)
        "id": "$elem.id.S",
        #if($foreach.hasNext),#end
        #end
      }
    EOF
  }
}

#You should change the response template as per the response structure and name of the keys you have. 
#Also, the two different response templates mentioned above are for example purposes only. 
#You have to choose one while deployed for returning the response. This is where REST shines by having different routes for different resources.

#Step 8 - Deployment of the API Gateway
#To use the API Gateway, we have to deploy it along with a stage. Anytime you need to change anything defined above, the API Gateway will be required to deploy again so new changes can come into effect. To fulfil this requirement, we will add a stage variable and assign the timestamp to it. So every time the plan is created, the deployment for API Gateway is forced.

# Deploying API Gateway
resource "aws_api_gateway_deployment" "exampleApiDeployment" {
  depends_on = [aws_api_gateway_integration.get-example-integration]

  rest_api_id = aws_api_gateway_rest_api.exampleApi.id
  stage_name  = var.stage_name

  variables = {
    "deployedAt" = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}
