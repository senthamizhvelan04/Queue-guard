output "api_url" { value = aws_apigatewayv2_api.http.api_endpoint }
output "orders_table_name" { value = aws_dynamodb_table.orders.name }
output "queue_name" { value = aws_sqs_queue.orders.name }
output "dlq_name" { value = aws_sqs_queue.dlq.name }
