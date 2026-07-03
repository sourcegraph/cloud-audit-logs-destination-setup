# Sourcegraph audit-log streaming to S3 — customer-side IAM + bucket.
#
# Federation model: GKE workload-identity. The collector presents its
# cluster-issued projected KSA token, so we federate the GKE cluster's OIDC
# issuer and match on the token's `aud` and the collector KSA's `sub`.
#
# One instance of this module = one collector writing to one bucket. The OIDC
# provider is created per-instance; this assumes each collector runs on a
# distinct GKE cluster (distinct issuer URL). Two instances sharing an issuer
# URL would conflict — AWS allows only one OIDC provider per issuer per account.

locals {
  gke_issuer_host_path = trimprefix(var.gke_cluster_issuer_url, "https://")
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

# TLS chain of the issuer host, used to populate the OIDC provider thumbprint.
# AWS no longer verifies the thumbprint for issuers backed by well-known CAs
# (it dropped that requirement in 2023), but the provider schema still
# requires the field. Reading it live keeps it correct if the CA rotates.
data "tls_certificate" "gke_issuer" {
  url = var.gke_cluster_issuer_url
}

resource "aws_iam_openid_connect_provider" "gke_cluster" {
  url             = var.gke_cluster_issuer_url
  client_id_list  = [local.audit_audience]
  thumbprint_list = [data.tls_certificate.gke_issuer.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "sourcegraph_audit_collector" {
  name = "${local.resource_prefix}-collector"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.gke_cluster.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.gke_issuer_host_path}:aud" = local.audit_audience
          "${local.gke_issuer_host_path}:sub" = var.collector_ksa_sub
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
