# DOFS Testing Guide

## Prerequisites
- AWS CLI configured with appropriate credentials
- Python 3.11+ installed
- Terraform 1.0+ installed
- Access to AWS Console (optional, for verification)

## Test Scenarios

### 1. Success Scenario
#### Steps:
1. Submit valid order:
```bash
curl -X POST https://<api-endpoint>/order \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "TEST-VALID-001",
    "customer_name": "Test User",
    "customer_email": "test@example.com",
    "items": [
      {
        "product_id": "PROD-001",
        "product_name": "Test Product",
        "quantity": 1,
        "unit_price": 25.99
      }
    ],
    "total_amount": 25.99,
    "shipping_address": {
      "street": "123 Test St",
      "city": "TestCity",
      "state": "TS",
      "zip_code": "12345"
    }
  }'
```

#### Verification:
1. Check Step Functions execution:
```bash
aws stepfunctions list-executions --state-machine-arn <step-function-arn>
```

2. Verify order in DynamoDB:
```bash
aws dynamodb get-item \
  --table-name <orders-table> \
  --key '{"order_id":{"S":"TEST-VALID-001"}}'
```

3. Check SQS queue:
```bash
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages
```

### 2. Failure & DLQ Handling
#### Steps:
1. Submit invalid order:
```bash
curl -X POST https://<api-endpoint>/order \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "TEST-INVALID-001",
    "customer_name": "",
    "items": [],
    "total_amount": -10
  }'
```

#### Verification:
1. Check Step Functions failure:
```bash
aws stepfunctions list-executions \
  --state-machine-arn <step-function-arn> \
  --status-filter FAILED
```

2. Verify failed order in DynamoDB:
```bash
aws dynamodb get-item \
  --table-name <failed-orders-table> \
  --key '{"order_id":{"S":"TEST-INVALID-001"}}'
```

3. Check DLQ:
```bash
aws sqs get-queue-attributes \
  --queue-url <dlq-url> \
  --attribute-names ApproximateNumberOfMessages
```

### 3. Automated Testing
Run the complete test suite:
```bash
./test_suite.sh
```

## Troubleshooting Guide

### Common Issues:

1. **API Gateway 5XX Errors**
   - Check Lambda logs: `aws logs get-log-events --log-group-name /aws/lambda/dofs-api-handler-dev`
   - Verify Lambda permissions
   - Check API Gateway configuration

2. **Step Functions Failures**
   - Check execution history: `aws stepfunctions get-execution-history`
   - Verify Lambda IAM roles
   - Check Lambda environment variables

3. **DynamoDB Issues**
   - Verify table exists: `aws dynamodb describe-table`
   - Check IAM permissions
   - Validate item format

4. **SQS/DLQ Issues**
   - Check queue attributes
   - Verify message format
   - Check Lambda trigger configuration

### Monitoring & Alerts

1. **CloudWatch Dashboards**
   - Access at: AWS Console → CloudWatch → Dashboards
   - Look for: `dofs-dashboard-<environment>`

2. **SNS Notifications**
   - Check email subscriptions
   - Verify SNS topic permissions
   - Monitor DLQ alerts

## CI/CD Pipeline Testing

### Pipeline Stages:
1. **Source**
   - Verify GitHub connection
   - Check branch configuration

2. **Build**
   - Monitor CodeBuild logs
   - Check artifact creation

3. **Plan**
   - Review Terraform plan
   - Check for resource changes

4. **Deploy**
   - Monitor deployment progress
   - Verify resource creation

### Pipeline Notifications:
- Check email for deployment notifications
- Monitor pipeline state changes
- Review CloudWatch events

## Performance Testing

### Metrics to Monitor:
1. **API Gateway**
   - Latency
   - Error rates
   - Request count

2. **Lambda Functions**
   - Duration
   - Error rate
   - Memory usage

3. **DynamoDB**
   - Read/Write capacity
   - Throttled requests
   - Scan/Query efficiency

4. **SQS**
   - Queue depth
   - Processing time
   - DLQ monitoring 