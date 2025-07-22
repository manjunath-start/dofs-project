#!/bin/bash
set -e

echo "=== DOFS Testing Suite ==="
cd terraform

# Get outputs and validate
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
ORDERS_TABLE=$(terraform output -raw orders_table_name 2>/dev/null || echo "")
FAILED_ORDERS_TABLE=$(terraform output -raw failed_orders_table_name 2>/dev/null || echo "")
STEP_FUNCTION_ARN=$(terraform output -raw step_function_arn 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")

# Validate required outputs
if [[ -z "$API_ENDPOINT" || -z "$ORDERS_TABLE" || -z "$FAILED_ORDERS_TABLE" || -z "$STEP_FUNCTION_ARN" ]]; then
    echo "❌ Error: Could not get required Terraform outputs. Make sure infrastructure is deployed."
    exit 1
fi

echo "🚀 API Endpoint: $API_ENDPOINT"
echo "📊 Orders Table: $ORDERS_TABLE"
echo "⚠️  Failed Orders Table: $FAILED_ORDERS_TABLE"
echo "🔄 Step Function: $STEP_FUNCTION_ARN"
echo "🌍 Region: $AWS_REGION"
echo "⏰ Testing started at: $(date)"
echo ""

# Generate unique order IDs with timestamp
TIMESTAMP=$(date +%s)
VALID_ORDER_ID="TEST-VALID-${TIMESTAMP}"
INVALID_ORDER_ID="TEST-INVALID-${TIMESTAMP}"

# Test 1: Valid Order
echo "📝 Test 1: Submitting valid order (ID: $VALID_ORDER_ID)..."
VALID_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{
    \"order_id\": \"$VALID_ORDER_ID\",
    \"customer_name\": \"Test User\",
    \"customer_email\": \"test@example.com\",
    \"items\": [{\"product_id\": \"PROD-001\", \"product_name\": \"Test Product\", \"quantity\": 1, \"unit_price\": 25.99}],
    \"total_amount\": 25.99,
    \"shipping_address\": {\"street\": \"123 Test St\", \"city\": \"TestCity\", \"state\": \"TS\", \"zip_code\": \"12345\"}
  }")

HTTP_CODE=$(echo "$VALID_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$VALID_RESPONSE" | sed '/HTTP_CODE:/d')

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "202" ]]; then
    echo "✅ Valid order submitted successfully"
    echo "   Response: $RESPONSE_BODY"
    VALID_EXECUTION_ARN=$(echo "$RESPONSE_BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('execution_arn', ''))" 2>/dev/null || echo "")
else
    echo "❌ Failed to submit valid order (HTTP $HTTP_CODE)"
    echo "   Response: $RESPONSE_BODY"
fi
echo ""

# Test 2: Invalid Order
echo "📝 Test 2: Submitting invalid order (ID: $INVALID_ORDER_ID)..."
INVALID_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{
    \"order_id\": \"$INVALID_ORDER_ID\",
    \"customer_name\": \"\",
    \"items\": [],
    \"total_amount\": -10
  }")

HTTP_CODE=$(echo "$INVALID_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$INVALID_RESPONSE" | sed '/HTTP_CODE:/d')

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "202" ]]; then
    echo "✅ Invalid order submitted successfully"
    echo "   Response: $RESPONSE_BODY"
    INVALID_EXECUTION_ARN=$(echo "$RESPONSE_BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('execution_arn', ''))" 2>/dev/null || echo "")
else
    echo "❌ Failed to submit invalid order (HTTP $HTTP_CODE)"
    echo "   Response: $RESPONSE_BODY"
fi
echo ""

# Wait for Step Functions processing
echo "⏳ Waiting for Step Functions to process orders (30 seconds)..."
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""

# Function to check Step Functions execution status
check_execution_status() {
    local execution_arn=$1
    local execution_name=$2
    
    if [[ -n "$execution_arn" ]]; then
        echo "🔍 Checking $execution_name execution status..."
        local status=$(aws stepfunctions describe-execution \
            --execution-arn "$execution_arn" \
            --region "$AWS_REGION" \
            --query 'status' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        echo "   Status: $status"
        
        if [[ "$status" == "FAILED" ]]; then
            echo "   Getting failure details..."
            aws stepfunctions describe-execution \
                --execution-arn "$execution_arn" \
                --region "$AWS_REGION" \
                --query 'error' \
                --output text 2>/dev/null || echo "   Could not retrieve error details"
        fi
        echo ""
    else
        echo "⚠️  No execution ARN available for $execution_name"
        echo ""
    fi
}

# Check execution statuses
echo "=== Step Functions Execution Status ==="
check_execution_status "$VALID_EXECUTION_ARN" "valid order"
check_execution_status "$INVALID_EXECUTION_ARN" "invalid order"

# Verify results in DynamoDB
echo "=== Database Verification ==="

echo "🔍 Checking valid orders in database..."
VALID_COUNT=$(aws dynamodb scan \
    --table-name "$ORDERS_TABLE" \
    --region "$AWS_REGION" \
    --select COUNT \
    --query 'Count' \
    --output text 2>/dev/null || echo "0")

if [[ "$VALID_COUNT" -gt 0 ]]; then
    echo "✅ Found $VALID_COUNT valid order(s) in database:"
    aws dynamodb scan \
        --table-name "$ORDERS_TABLE" \
        --region "$AWS_REGION" \
        --query 'Items[*].[order_id.S, customer_name.S, total_amount.N, order_status.S]' \
        --output table 2>/dev/null || echo "   Could not retrieve order details"
else
    echo "⚠️  No valid orders found in database"
fi
echo ""

echo "🔍 Checking failed orders in database..."
FAILED_COUNT=$(aws dynamodb scan \
    --table-name "$FAILED_ORDERS_TABLE" \
    --region "$AWS_REGION" \
    --select COUNT \
    --query 'Count' \
    --output text 2>/dev/null || echo "0")

if [[ "$FAILED_COUNT" -gt 0 ]]; then
    echo "✅ Found $FAILED_COUNT failed order(s) in database:"
    aws dynamodb scan \
        --table-name "$FAILED_ORDERS_TABLE" \
        --region "$AWS_REGION" \
        --query 'Items[*].[order_id.S, error_message.S, failed_at.S]' \
        --output table 2>/dev/null || echo "   Could not retrieve failed order details"
else
    echo "⚠️  No failed orders found in database"
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo "⏰ Testing completed at: $(date)"
echo "📊 Valid orders in database: $VALID_COUNT"
echo "❌ Failed orders in database: $FAILED_COUNT"

# Additional diagnostics
echo ""
echo "=== Recent Step Functions Executions ==="
aws stepfunctions list-executions \
    --state-machine-arn "$STEP_FUNCTION_ARN" \
    --region "$AWS_REGION" \
    --max-items 5 \
    --query 'executions[*].[name, status, startDate]' \
    --output table 2>/dev/null || echo "Could not retrieve execution list"

echo ""
echo "🏁 Test suite completed successfully!"
