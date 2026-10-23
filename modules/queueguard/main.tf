data "archive_file" "ingress" {
  type        = "zip"
  source_file = "${path.root}/app/ingress.py"
  output_path = "${path.module}/ingress.zip"
}
data "archive_file" "worker" {
  type        = "zip"
  source_file = "${path.root}/app/worker.py"
  output_path = "${path.module}/worker.zip"
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name_prefix}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "orders" {
  name                       = "${var.name_prefix}-orders"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_dynamodb_table" "orders" {
  name         = "${var.name_prefix}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"
  attribute { name = "order_id", type = "S" }
  server_side_encryption { enabled = true }
  point_in_time_recovery { enabled = true }
}

resource "aws_iam_role" "ingress" {
  name = "${var.name_prefix}-ingress-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ingress_logs" {
  role       = aws_iam_role.ingress.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "ingress_send" {
  name = "${var.name_prefix}-send-to-queue"
  role = aws_iam_role.ingress.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow", Action = ["sqs:SendMessage"],
      Resource = aws_sqs_queue.orders.arn
    }]
  })
}

resource "aws_iam_role" "worker" {
  name = "${var.name_prefix}-worker-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "worker_logs" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "worker_access" {
  name = "${var.name_prefix}-worker-access"
  role = aws_iam_role.worker.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.orders.arn },
      { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"], Resource = aws_sqs_queue.orders.arn }
    ]
  })
}

resource "aws_cloudwatch_log_group" "ingress" {
  name              = "/aws/lambda/${var.name_prefix}-ingress"
  retention_in_days = var.log_retention_days
}
resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/lambda/${var.name_prefix}-worker"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "ingress" {
  function_name    = "${var.name_prefix}-ingress"
  role             = aws_iam_role.ingress.arn
  handler          = "ingress.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.ingress.output_path
  source_code_hash = data.archive_file.ingress.output_base64sha256
  timeout          = 10
  environment {
    variables = { QUEUE_URL = aws_sqs_queue.orders.id }
  }
  depends_on = [aws_cloudwatch_log_group.ingress, aws_iam_role_policy_attachment.ingress_logs, aws_iam_role_policy.ingress_send]
}

resource "aws_lambda_function" "worker" {
  function_name    = "${var.name_prefix}-worker"
  role             = aws_iam_role.worker.arn
  handler          = "worker.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.worker.output_path
  source_code_hash = data.archive_file.worker.output_base64sha256
  timeout          = 30
  environment {
    variables = { TABLE_NAME = aws_dynamodb_table.orders.name }
  }
  depends_on = [aws_cloudwatch_log_group.worker, aws_iam_role_policy_attachment.worker_logs, aws_iam_role_policy.worker_access]
}

resource "aws_lambda_event_source_mapping" "orders" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 1
  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
}
resource "aws_apigatewayv2_integration" "ingress" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingress.invoke_arn
  payload_format_version = "2.0"
}
resource "aws_apigatewayv2_route" "orders" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /orders"
  target    = "integrations/${aws_apigatewayv2_integration.ingress.id}"
}
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}
resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingress.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "sqs" {
  statement_id  = "AllowSqsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.worker.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.orders.arn
}

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
}
resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  alarm_name          = "${var.name_prefix}-queue-depth"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 20
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { QueueName = aws_sqs_queue.orders.name }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.name_prefix}-dlq-not-empty"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { QueueName = aws_sqs_queue.dlq.name }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
