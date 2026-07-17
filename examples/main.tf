# Example: one Sourcegraph audit-log collector → one S3 bucket.
# Provider (region, profile) is configured by you, the caller.

provider "aws" {
  region = "us-east-1"
}

module "audit_logs_destination" {
  source = "git::https://github.com/sourcegraph/cloud-audit-logs-destination-setup.git?ref=v1.0.0"

  bucket_name = "acme-audit-logs"

  # Numeric unique ID of the Sourcegraph collector GSA. Provided by Sourcegraph.
  collector_gsa_unique_id = "<provided by Sourcegraph>"
}

# Report this ARN (and the bucket name) back to your Sourcegraph contact.
output "sourcegraph_audit_role_arn" {
  value = module.audit_logs_destination.sourcegraph_audit_role_arn
}

output "sourcegraph_audit_bucket_name" {
  value = module.audit_logs_destination.sourcegraph_audit_bucket_name
}
