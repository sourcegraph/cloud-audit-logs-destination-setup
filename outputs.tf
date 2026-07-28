output "sourcegraph_audit_role_arns" {
  description = "Collector key => role ARN. Report these back to your Sourcegraph contact."
  value       = { for k, r in aws_iam_role.sourcegraph_audit_collector : k => r.arn }
}

output "sourcegraph_audit_bucket_name" {
  value = aws_s3_bucket.audit_logs.bucket
}
