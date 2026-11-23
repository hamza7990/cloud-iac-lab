#!/usr/bin/env bash
# Checks the dev environment that Terraform just built in LocalStack.
# Usage: scripts/smoke.sh   (run from the repo root, after terraform apply)
set -euo pipefail

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
aws_() { aws --endpoint-url "$ENDPOINT" "$@"; }

tf_out() { terraform -chdir=envs/dev output -raw "$1"; }

FUNCTION="$(tf_out function_name)"
TABLE="$(tf_out table_name)"
BUCKET="$(tf_out bucket_name)"
VPC="$(tf_out vpc_id)"

echo "== 1. bucket exists and has versioning on"
aws_ s3api head-bucket --bucket "$BUCKET"
STATUS="$(aws_ s3api get-bucket-versioning --bucket "$BUCKET" --query Status --output text)"
[ "$STATUS" = "Enabled" ] || { echo "versioning is $STATUS"; exit 1; }
aws_ s3 cp - "s3://$BUCKET/hello.txt" <<< "hello"
aws_ s3 ls "s3://$BUCKET/"

echo "== 2. network: 2 public + 2 private subnets in the VPC"
COUNT="$(aws_ ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'length(Subnets)' --output text)"
[ "$COUNT" = "4" ] || { echo "expected 4 subnets, got $COUNT"; exit 1; }

echo "== 3. wait for the Lambda function to be active"
aws_ lambda wait function-active-v2 --function-name "$FUNCTION"

invoke() {
  # $1 = JSON event, prints the function result
  aws_ lambda invoke --function-name "$FUNCTION" \
    --cli-binary-format raw-in-base64-out --payload "$1" /tmp/out.json > /dev/null
  cat /tmp/out.json
  echo
}

echo "== 4. invoke: /health"
invoke '{"rawPath":"/health","requestContext":{"http":{"method":"GET"}}}' \
  | jq -e '.statusCode == 200' > /dev/null

echo "== 5. invoke: POST /items"
invoke '{"rawPath":"/items","requestContext":{"http":{"method":"POST"}},"body":"{\"id\":\"smoke-1\",\"value\":\"works\"}"}' \
  | jq -e '.statusCode == 201' > /dev/null

echo "== 6. invoke: GET /items?id=smoke-1"
invoke '{"rawPath":"/items","requestContext":{"http":{"method":"GET"}},"queryStringParameters":{"id":"smoke-1"}}' \
  | jq -e '.body | fromjson | .value == "works"' > /dev/null

echo "== 7. the item is really in DynamoDB"
aws_ dynamodb get-item --table-name "$TABLE" \
  --key '{"id":{"S":"smoke-1"}}' --query 'Item.value.S' --output text | grep -q works

echo "smoke test passed"
