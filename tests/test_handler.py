import json

import boto3
import handler
import pytest
from moto import mock_aws


@pytest.fixture
def table(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "test")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "test")
    monkeypatch.setenv("TABLE_NAME", "items")
    handler._table = None
    with mock_aws():
        boto3.client("dynamodb").create_table(
            TableName="items",
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        yield
    handler._table = None


def event(method, path, body=None, query=None):
    return {
        "rawPath": path,
        "requestContext": {"http": {"method": method}},
        "body": json.dumps(body) if body is not None else None,
        "queryStringParameters": query,
    }


def test_health_needs_no_table():
    out = handler.handler(event("GET", "/health"), None)
    assert out["statusCode"] == 200


def test_unknown_path():
    assert handler.handler(event("GET", "/nope"), None)["statusCode"] == 404


def test_put_then_get(table):
    created = handler.handler(event("POST", "/items", {"id": "a", "value": "1"}), None)
    assert created["statusCode"] == 201
    got = handler.handler(event("GET", "/items", query={"id": "a"}), None)
    assert got["statusCode"] == 200
    assert json.loads(got["body"]) == {"id": "a", "value": "1"}


def test_get_missing_item(table):
    out = handler.handler(event("GET", "/items", query={"id": "x"}), None)
    assert out["statusCode"] == 404


def test_post_validation(table):
    bad = handler.handler(event("POST", "/items", {"id": "a"}), None)
    assert bad["statusCode"] == 400


def test_post_invalid_json(table):
    e = event("POST", "/items")
    e["body"] = "{not json"
    assert handler.handler(e, None)["statusCode"] == 400


def test_get_without_id(table):
    assert handler.handler(event("GET", "/items"), None)["statusCode"] == 400


def test_method_not_allowed(table):
    assert handler.handler(event("DELETE", "/items"), None)["statusCode"] == 405
