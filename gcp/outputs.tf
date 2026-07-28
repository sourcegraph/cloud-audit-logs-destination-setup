output "sourcegraph_audit_bucket_name" {
  description = "Destination bucket name. Report this back to your Sourcegraph contact — on GCS there is no role ARN."
  value       = google_storage_bucket.audit_logs.name
}

# Lets the customer confirm the bindings exist without reading the bucket policy.
output "sourcegraph_audit_gcs_bindings" {
  description = "Collector key => bucket IAM members created for its GSA."
  value = {
    for k, m in google_storage_bucket_iam_member.object_creator : k => {
      member = m.member
      roles  = [m.role, google_storage_bucket_iam_member.bucket_reader[k].role]
    }
  }
}
