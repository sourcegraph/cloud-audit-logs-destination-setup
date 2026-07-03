# audit-collector-bucket-setup

Customer-side AWS resources that grant one Sourcegraph audit-log (OTel)
collector write access to an S3 bucket. One module instance = one collector →
one bucket.

Creates: the destination S3 bucket (versioned, KMS-encrypted, public access
blocked), an IAM OIDC provider for the collector's GKE cluster issuer, and a
web-identity IAM role + write-only S3 policy the collector assumes.

## Federation model

GKE workload-identity. The collector presents its cluster-issued projected KSA
token; the role's trust policy matches on the token `aud`
(`sourcegraph_audit_audience`) and the collector KSA `sub` (`collector_ksa_sub`).

## One OIDC provider per issuer

AWS allows only one `aws_iam_openid_connect_provider` per issuer URL per
account. This module creates the provider per instance, so **each instance must
use a distinct `gke_cluster_issuer_url`** (distinct GKE cluster). Two collectors
on the same cluster would collide — share the provider externally in that case.

## Usage

```hcl
module "my_collector" {
  source = "../../modules/audit-collector-bucket-setup"

  bucket_name            = "acme-audit-logs"
  gke_cluster_issuer_url = "https://container.googleapis.com/v1/projects/.../clusters/..."
  collector_ksa_sub      = "system:serviceaccount:<ns>:audit-log-stream-collector"
}
```

The IAM role and policy names default to `bucket_name`, which is unique per
collector, so two instances in one account never collide — no `resource_prefix`
needed. Set `resource_prefix` only to override the derived name. Provider config
(region, profile) is inherited from the caller. Outputs: role ARN, bucket name,
OIDC provider ARN — hand the role ARN and bucket back to your Sourcegraph contact
(phase 2 of the enablement).
