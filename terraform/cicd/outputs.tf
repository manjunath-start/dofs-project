# CodeBuild Project Outputs
output "build_project_name" {
  description = "Name of the main build project"
  value       = aws_codebuild_project.build_project.name
}

output "build_project_arn" {
  description = "ARN of the main build project"
  value       = aws_codebuild_project.build_project.arn
}

output "terraform_plan_project_name" {
  description = "Name of the Terraform plan project"
  value       = aws_codebuild_project.terraform_plan.name
}

output "terraform_plan_project_arn" {
  description = "ARN of the Terraform plan project"
  value       = aws_codebuild_project.terraform_plan.arn
}

output "terraform_apply_project_name" {
  description = "Name of the Terraform apply project"
  value       = aws_codebuild_project.terraform_apply.name
}

output "terraform_apply_project_arn" {
  description = "ARN of the Terraform apply project"
  value       = aws_codebuild_project.terraform_apply.arn
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild service role"
  value       = aws_iam_role.codebuild_role.arn
}

output "codebuild_log_group_name" {
  description = "Name of the CodeBuild CloudWatch log group"
  value       = aws_cloudwatch_log_group.codebuild_logs.name
}

# CodePipeline Outputs
output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.main.name
}

output "codepipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.main.arn
}

output "codepipeline_role_arn" {
  description = "ARN of the CodePipeline service role"
  value       = aws_iam_role.codepipeline_role.arn
}

output "artifacts_bucket_name" {
  description = "Name of the S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = aws_sns_topic.pipeline_notifications.arn
} 