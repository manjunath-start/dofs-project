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

## Additional Notes

- **.gitignore** is configured to exclude build artifacts, state files, and virtual environments.
- **Manual resource deletion:** Use `terraform destroy -auto-approve` to clean up all resources.
- **For advanced troubleshooting:** Check the AWS Console for resource status and CloudWatch logs for Lambda and CodeBuild.
