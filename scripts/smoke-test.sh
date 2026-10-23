#!/usr/bin/env bash
set -euo pipefail
: "${API_URL:?Set API_URL to the Terraform api_url output}"
ORDER_ID="smoke-$(date +%s)"
response="$(curl --fail-with-body --silent --show-error \
  -X POST "${API_URL%/}/orders" \
  -H 'content-type: application/json' \
  -d "{\"order_id\":\"${ORDER_ID}\",\"customer_id\":\"smoke-test\",\"items\":[{\"sku\":\"demo-item\",\"quantity\":1}]}")"
echo "$response"
echo "$response" | grep -q "$ORDER_ID"
echo "QueueGuard API accepted order $ORDER_ID"
