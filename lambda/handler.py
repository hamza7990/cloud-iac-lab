"""Small items API behind a Lambda function URL.

POST /items  {"id": "a", "value": "b"}  stores an item in DynamoDB
GET  /items?id=a                         reads it back
GET  /health                             answers without touching DynamoDB
"""

import json
import os

import boto3

_table = None


def table():
    """Create the DynamoDB table handle once per container."""
    global _table
    if _table is None:
        _table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
    return _table


def response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    http = event.get("requestContext", {}).get("http", {})
    method = http.get("method", "GET")
    path = event.get("rawPath", "/")

    if path == "/health":
        return response(200, {"status": "ok"})

    if path != "/items":
        return response(404, {"error": "not found"})

    if method == "POST":
        try:
            data = json.loads(event.get("body") or "{}")
        except json.JSONDecodeError:
            return response(400, {"error": "body is not valid JSON"})
        if not data.get("id") or "value" not in data:
            return response(400, {"error": "id and value are required"})
        table().put_item(Item={"id": str(data["id"]), "value": str(data["value"])})
        return response(201, {"id": data["id"]})

    if method == "GET":
        item_id = (event.get("queryStringParameters") or {}).get("id")
        if not item_id:
            return response(400, {"error": "id is required"})
        item = table().get_item(Key={"id": item_id}).get("Item")
        if item is None:
            return response(404, {"error": "no such item"})
        return response(200, item)

    return response(405, {"error": "method not allowed"})
