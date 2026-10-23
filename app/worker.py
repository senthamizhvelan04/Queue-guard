import json
import os
import boto3
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

def handler(event, context):
    failures = []
    for record in event.get("Records", []):
        try:
            order = json.loads(record["body"])
            table.put_item(Item={
                "order_id": order["order_id"],
                "customer_id": order["customer_id"],
                "items": order["items"],
                "status": "PROCESSED",
                "processed_at": datetime.now(timezone.utc).isoformat()
            })
            print(json.dumps({"event": "order_processed", "order_id": order["order_id"]}))
        except Exception as exc:
            print(json.dumps({"event": "order_processing_failed", "error": str(exc)}))
            failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": failures}
