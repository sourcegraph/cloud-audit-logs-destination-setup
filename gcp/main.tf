# Sourcegraph audit-log streaming to GCS — customer-side bucket + IAM.
#
# No federation, unlike the AWS root module: the collector's GSA authenticates to
# Google directly, so access is a pair of bucket-scoped IAM bindings on that GSA.
# No role, no trust policy, no OIDC provider, no unique ID.
#
# One module instance owns one bucket and N collector grants. The bucket and its
# configuration are singular, so a shared bucket has exactly one Terraform owner;
# each collector writes under its own src-<id>/ key prefix.

resource "google_storage_bucket" "audit_logs" {
  #checkov:skip=CKV_GCP_62: access logging is the customer's call — it needs a
  # second bucket in their project, and the audit objects are the artifact here.
  name     = var.bucket_name
  location = var.location

  # Bucket-level IAM only: ACLs would let an object writer set per-object
  # readers, bypassing the two bindings below.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # GCS encrypts at rest unconditionally, so there is no SSE analogue to set;
  # a CMEK block would be the equivalent of the S3 KMS rule but needs a
  # customer-supplied key, so it stays out of scope here.
}

# Write access. _member (not _binding/_policy) is additive, so it leaves any
# unrelated bindings the customer already has on the bucket untouched.
resource "google_storage_bucket_iam_member" "object_creator" {
  for_each = var.collectors

  bucket = google_storage_bucket.audit_logs.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${each.value}"
}

# storage.buckets.get, which the exporter needs because reuse_if_exists probes
# the bucket before the first write. No narrower predefined role grants it.
resource "google_storage_bucket_iam_member" "bucket_reader" {
  for_each = var.collectors

  bucket = google_storage_bucket.audit_logs.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${each.value}"
}
