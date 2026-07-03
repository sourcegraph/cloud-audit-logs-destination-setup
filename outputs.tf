output "sourcegraph_audit_role_arn" {
  description = "Report this ARN back to your Sourcegraph contact."
  value       = aws_iam_role.sourcegraph_audit_collector.arn
}

output "sourcegraph_audit_bucket_name" {
  value = aws_s3_bucket.audit_logs.bucket
}
