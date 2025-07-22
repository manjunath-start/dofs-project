# DOFS Project

## Prerequisites

- **AWS Account** with permissions to create and manage S3, DynamoDB, Lambda, SQS, API Gateway, IAM, CodeBuild, CodePipeline, and CodeStar Connections.
- **AWS CLI** installed and configured (`aws configure`).
- **Terraform** v1.0 or newer.
- **Python 3.11+** (for Lambda packaging and local testing).
- **Git** for version control.
- **GitHub Account** (for CI/CD integration).
- **GitHub Personal Access Token** (for CodeStar Connection setup, if not already connected).

---

## Setup Instructions

### 1. **Clone the Repository**
```bash
git clone https://github.com/<your-username>/<your-repo-name>.git
cd <your-repo-name>
```

### 2. **Create and Activate Python Virtual Environment**
```bash
python3 -m venv dofs-venv
source dofs-venv/bin/activate
```

### 3. **Configure AWS Credentials**
```bash
aws configure
```
Ensure your credentials have sufficient permissions.

### 4. **Prepare Lambda Deployment Packages**
For each Lambda in `lambdas/<lambda_name>/`, create a `deployment.zip`:
```bash
cd lambdas/<lambda_name>
zip deployment.zip lambda_function.py  # Add any dependencies as needed
cd ../..
```
Repeat for all Lambda functions.

### 5. **Set Up Terraform Backend Resources**
- Ensure the S3 bucket and DynamoDB table for state locking exist (see `backend.tf`).
- If they already exist, comment out the resource blocks in `backend.tf`.

### 6. **Initialize Terraform**
```bash
cd terraform
terraform init
```

### 7. **Set Up CodeStar Connection (for CI/CD)**
- In AWS Console, go to CodeStar Connections and create a connection to GitHub.
- Copy the ARN and update `variables.tf` (`codestar_connection_arn`).

### 8. **Apply Terraform**
```bash
terraform apply
```
This will provision all AWS resources and set up the CI/CD pipeline.

---

## Troubleshooting

### **Common Issues & Fixes**

- **DynamoDB Table Already Exists**
  - Comment out or remove the `aws_dynamodb_table.terraform_locks` resource in `backend.tf` after initial creation.

- **API Gateway CORS/Integration Errors**
  - Ensure all CORS headers in `aws_api_gateway_integration_response` are static values wrapped in single quotes.
  - Ensure `aws_api_gateway_method_response` uses booleans for CORS headers.

- **Invalid Index for SQS ARN**
  - Use `element(split(":", var.dlq_arn), 5)` to extract the queue name from the ARN.

- **Missing Lambda Deployment Packages**
  - Ensure `deployment.zip` exists in each Lambda directory before running `terraform apply`.

- **CodePipeline GitHub v1 Warning**
  - Use CodeStar Connections (GitHub v2) as shown in the pipeline explanation below.

- **Missing CodeStar Connection ARN**
  - Make sure `codestar_connection_arn` is set in your root `variables.tf` and passed to the `cicd` module.

- **AWS Permissions**
  - Ensure your AWS user/role has permissions for all required services.

---

## Pipeline Explanation

### **CI/CD Pipeline (AWS CodePipeline + CodeBuild)**

- **Source Stage:**  
  Uses AWS CodeStar Connection to securely connect to your GitHub repository. Triggers on changes to the specified branch.

- **Build Stage:**  
  Runs CodeBuild to build and package your application (including Lambda deployment zips).

- **Plan Stage:**  
  Runs `terraform plan` in CodeBuild, outputting the plan for review.

- **Approval Stage:**  
  Manual approval step before applying infrastructure changes.

- **Deploy Stage:**  
  Runs `terraform apply` in CodeBuild to deploy infrastructure changes.

- **Notifications:**  
  Pipeline state changes and approvals are sent to an SNS topic, which can email alerts to your team.

### **Key Files**
- `terraform/main.tf`: Main infrastructure definition.
- `terraform/backend.tf`: Backend configuration for state storage.
- `terraform/cicd/codepipeline.tf`: CI/CD pipeline definition.
- `buildspec.yml`, `buildspec-plan.yml`, `buildspec-apply.yml`: Build instructions for CodeBuild.
- `lambdas/*/deployment.zip`: Lambda deployment packages.

---

## Testing Guide

### **Prerequisites for Testing**
Ensure infrastructure is deployed and all Terraform outputs are available:
```bash
cd terraform
terraform output
```

### **1. Success Scenario Testing**

#### **Run Automated Test Suite**
```bash
# From project root
./test_suite.sh
```

#### **Manual Success Testing**
```bash
# Get API endpoint
API_ENDPOINT=$(cd terraform && terraform output -raw api_endpoint)

# Submit valid order
curl -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "TEST-VALID-001",
    "customer_name": "John Doe",
    "customer_email": "john@example.com",
    "items": [
      {
        "product_id": "PROD-001",
        "product_name": "Test Product",
        "quantity": 2,
        "unit_price": 29.99
      }
    ],
    "total_amount": 59.98,
    "shipping_address": {
      "street": "123 Main St",
      "city": "Anytown",
      "state": "CA",
      "zip_code": "12345"
    }
  }'
```

#### **Verify Success Results**
```bash
# Check orders in DynamoDB
aws dynamodb scan --table-name dofs-orders-dev --region us-west-2

# Check Step Functions execution
aws stepfunctions list-executions \
  --state-machine-arn $(cd terraform && terraform output -raw step_function_arn) \
  --region us-west-2
```

### **2. Failure and DLQ Handling Testing**

#### **Test Invalid Order (Missing Required Fields)**
```bash
# Submit order with missing customer_name
curl -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "TEST-INVALID-001",
    "customer_name": "",
    "customer_email": "invalid-email",
    "items": [],
    "total_amount": -10
  }'
```

#### **Test Invalid Order (Bad Data)**
```bash
# Submit order with negative amount and invalid email
curl -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "TEST-INVALID-002",
    "customer_name": "Test User",
    "customer_email": "not-an-email",
    "items": [
      {
        "product_id": "PROD-001",
        "quantity": -1,
        "unit_price": -5.00
      }
    ],
    "total_amount": -10
  }'
```

#### **Verify DLQ Processing**
```bash
# Wait 30-60 seconds for processing, then check failed orders table
aws dynamodb scan --table-name dofs-failed-orders-dev --region us-west-2

# Check DLQ messages
aws sqs get-queue-attributes \
  --queue-url $(cd terraform && terraform output -raw dlq_url) \
  --attribute-names ApproximateNumberOfMessages \
  --region us-west-2

# Check DLQ processor Lambda logs
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/dofs-dlq-processor-dev" \
  --region us-west-2
```

#### **Monitor DLQ Alerts**
```bash
# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-names "dofs-dlq-messages-dev" \
  --region us-west-2

# View CloudWatch dashboard
echo "Dashboard URL: https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=dofs-dashboard-dev"
```

### **3. CI/CD System Testing**

#### **Test Terraform Plan Pipeline**
```bash
# Make a small change to trigger pipeline
echo "# Updated $(date)" >> terraform/README_PIPELINE.md
git add .
git commit -m "Test CI/CD pipeline - Terraform plan"
git push origin develop
```

#### **Monitor Pipeline Execution**
```bash
# List pipeline executions
aws codepipeline list-pipeline-executions \
  --pipeline-name "dofs-pipeline-dev" \
  --region us-west-2

# Get specific execution details
EXECUTION_ID=$(aws codepipeline list-pipeline-executions \
  --pipeline-name "dofs-pipeline-dev" \
  --region us-west-2 \
  --query 'pipelineExecutionSummaries[0].pipelineExecutionId' \
  --output text)

aws codepipeline get-pipeline-execution \
  --pipeline-name "dofs-pipeline-dev" \
  --pipeline-execution-id "$EXECUTION_ID" \
  --region us-west-2
```

#### **Test Manual Approval Process**
```bash
# Check pipeline status (should be waiting for approval)
aws codepipeline get-pipeline-state \
  --name "dofs-pipeline-dev" \
  --region us-west-2

# Approve the pipeline (if needed)
aws codepipeline put-approval-result \
  --pipeline-name "dofs-pipeline-dev" \
  --stage-name "Approval" \
  --action-name "ManualApproval" \
  --result summary="Approved for testing",status="Approved" \
  --token "<approval-token-from-pipeline-state>" \
  --region us-west-2
```

#### **Verify CodeBuild Logs**
```bash
# Get build project logs
aws logs describe-log-streams \
  --log-group-name "/aws/codebuild/dofs-dev" \
  --region us-west-2

# View specific log stream
aws logs get-log-events \
  --log-group-name "/aws/codebuild/dofs-dev" \
  --log-stream-name "<log-stream-name>" \
  --region us-west-2
```

### **4. End-to-End Testing Scenarios**

#### **Complete Order Lifecycle Test**
```bash
# 1. Submit valid order
ORDER_ID="E2E-TEST-$(date +%s)"
curl -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{
    \"order_id\": \"$ORDER_ID\",
    \"customer_name\": \"E2E Test User\",
    \"customer_email\": \"e2e@test.com\",
    \"items\": [{
      \"product_id\": \"PROD-E2E\",
      \"product_name\": \"E2E Test Product\",
      \"quantity\": 1,
      \"unit_price\": 99.99
    }],
    \"total_amount\": 99.99
  }"

# 2. Wait and check order status
sleep 30
aws dynamodb get-item \
  --table-name dofs-orders-dev \
  --key "{\"order_id\":{\"S\":\"$ORDER_ID\"}}" \
  --region us-west-2
```

#### **Load Testing (Optional)**
```bash
# Submit multiple orders concurrently
for i in {1..10}; do
  curl -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{
      \"order_id\": \"LOAD-TEST-$i-$(date +%s)\",
      \"customer_name\": \"Load Test User $i\",
      \"customer_email\": \"loadtest$i@example.com\",
      \"items\": [{
        \"product_id\": \"PROD-LOAD\",
        \"quantity\": 1,
        \"unit_price\": 10.00
      }],
      \"total_amount\": 10.00
    }" &
done
wait
```

### **5. Cleanup and Reset Testing Environment**

#### **Clear Test Data**
```bash
# Clear all orders from both tables
aws dynamodb scan --table-name dofs-orders-dev --region us-west-2 --query 'Items[*].order_id.S' --output text | xargs -I {} aws dynamodb delete-item --table-name dofs-orders-dev --region us-west-2 --key '{"order_id":{"S":"{}"}}'

aws dynamodb scan --table-name dofs-failed-orders-dev --region us-west-2 --query 'Items[*].order_id.S' --output text | xargs -I {} aws dynamodb delete-item --table-name dofs-failed-orders-dev --region us-west-2 --key '{"order_id":{"S":"{}"}}'

# Verify tables are empty
aws dynamodb scan --table-name dofs-orders-dev --region us-west-2 --select COUNT
aws dynamodb scan --table-name dofs-failed-orders-dev --region us-west-2 --select COUNT
```

#### **Reset Pipeline State**
```bash
# Stop any running pipeline executions
aws codepipeline stop-pipeline-execution \
  --pipeline-name "dofs-pipeline-dev" \
  --pipeline-execution-id "$EXECUTION_ID" \
  --abandon \
  --region us-west-2
```

### **Expected Test Results**

- ✅ **Valid orders**: Should appear in `dofs-orders-dev` table with status `VALIDATED` or `FULFILLED`
- ✅ **Invalid orders**: Should appear in `dofs-failed-orders-dev` table with error details
- ✅ **Step Functions**: Valid orders show `SUCCEEDED`, invalid orders trigger DLQ processing
- ✅ **CI/CD Pipeline**: Should complete all stages (Source → Build → Plan → Approval → Deploy)
- ✅ **Notifications**: SNS alerts should be sent for DLQ threshold breaches and pipeline state changes

---

## Additional Notes

- **.gitignore** is configured to exclude build artifacts, state files, and virtual environments.
- **Manual resource deletion:** Use `terraform destroy -auto-approve` to clean up all resources.
- **For advanced troubleshooting:** Check the AWS Console for resource status and CloudWatch logs for Lambda and CodeBuild.
