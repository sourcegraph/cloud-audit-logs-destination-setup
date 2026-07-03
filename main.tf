# Sourcegraph audit-log streaming to S3 — customer-side IAM + bucket.
#
# Federation model: Google service account. The collector's refresher sidecar
# presents a GSA-signed accounts.google.com ID token, so trust keys only on the
# Sourcegraph GSA (its numeric unique ID) — never on the GKE cluster. This is
# the same shape LogPush uses; there is no per-cluster OIDC provider, so a DR
# cluster-swap needs no customer change.

locals {
  # Default IAM names off the (unique-per-collector) bucket so two instances
  # in one account never collide. Override with resource_prefix if needed.
  resource_prefix = coalesce(var.resource_prefix, var.bucket_name)
  audit_audience  = coalesce(var.sourcegraph_audit_audience, "sourcegraph-otel-audit-aws")
}

resource "aws_s3_bucket" "audit_logs" {
  #checkov:skip=CKV_AWS_18: dev testing bucket, access logging not required
  #checkov:skip=CKV_AWS_144: dev testing bucket, cross-region replication not required
  #checkov:skip=CKV_AWS_19: dev testing bucket, default SSE-S3 is sufficient
  #checkov:skip=CKV_AWS_145: dev testing bucket, KMS CMK not required
  #checkov:skip=CKV_AWS_21: dev testing bucket, versioning not required
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Federated principal is Google's global issuer — no per-cluster OIDC provider,
# no thumbprint. Both aud and sub match the collector GSA's numeric unique ID
# (Google sets aud == sub == uniqueId); oaud is the audience constant.
resource "aws_iam_role" "sourcegraph_audit_collector" {
  name = "${local.resource_prefix}-collector"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = "accounts.google.com" }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "accounts.google.com:aud"  = var.collector_gsa_unique_id
          "accounts.google.com:sub"  = var.collector_gsa_unique_id
          "accounts.google.com:oaud" = local.audit_audience
        }
      }
    }]
  })
}

resource "aws_iam_policy" "sourcegraph_audit_s3_access" {
  name = "${local.resource_prefix}-s3-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "OtelAuditExporterWrite"
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "arn:aws:s3:::${aws_s3_bucket.audit_logs.bucket}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sourcegraph_audit_attach" {
  role       = aws_iam_role.sourcegraph_audit_collector.name
  policy_arn = aws_iam_policy.sourcegraph_audit_s3_access.arn
}
