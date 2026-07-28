# Example: a Sourcegraph audit-log collector → a customer-owned GCS bucket.
# Provider (project, region) is configured by you, the caller.

provider "google" {
  project = "acme-prod"
  region  = "us-central1"
}

module "audit_logs_destination" {
  source = "git::https://github.com/sourcegraph/cloud-audit-logs-destination-setup.git//gcp?ref=v2.1.0"

  bucket_name = "acme-audit-logs"
  location    = "US"

  # Sourcegraph instance ID => the collector's GCP service-account email. Both
  # provided by Sourcegraph. Add an entry per instance to share this bucket.
  collectors = {
    "src-a1b2c3" = "<collector GSA email, provided by Sourcegraph>"
  }
}

# On GCS there is no role ARN — report the bucket name to your Sourcegraph
# contact. The bindings output is for your own verification.
output "sourcegraph_audit_bucket_name" {
  value = module.audit_logs_destination.sourcegraph_audit_bucket_name
}

output "sourcegraph_audit_gcs_bindings" {
  value = module.audit_logs_destination.sourcegraph_audit_gcs_bindings
}
