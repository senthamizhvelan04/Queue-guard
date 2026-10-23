import json
import os
import uuid
import boto3

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]

def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {"statusCode": 400, "headers": {"content-type": "application/json"},
                "body": json.dumps({"error": "Request body must be valid JSON"})}

    order_id = body.get("order_id")
    customer_id = body.get("customer_id")
    items = body.get("items")
    if not isinstance(order_id, str) or not order_id.strip():
        return {"statusCode": 400, "body": json.dumps({"error": "order_id is required"})}
    if not isinstance(customer_id, str) or not customer_id.strip():
        return {"statusCode": 400, "body": json.dumps({"error": "customer_id is required"})}
    if not isinstance(items, list) or not items:
        return {"statusCode": 400, "body": json.dumps({"error": "items must be a non-empty list"})}

    message = {
        "order_id": order_id,
        "customer_id": customer_id,
        "items": items,
        "request_id": context.aws_request_id or str(uuid.uuid4())
    }
    sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(message))
    return {"statusCode": 202, "headers": {"content-type": "application/json"},
            "body": json.dumps({"message": "Order accepted for processing", "order_id": order_id})}
