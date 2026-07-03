# Cloud Audit Logs Destination Setup

Customer-side AWS resources that grant one Sourcegraph audit-log collector
write access to an S3 bucket. One module instance = one collector → one bucket.

Creates: the destination S3 bucket (versioned, KMS-encrypted, public access
blocked), an IAM OIDC provider, and a web-identity IAM role + write-only S3
policy the collector assumes.

> **Use `ref=v0.1.0`** — the supported version today. Later tags (`v1.0.0`+)
> are still in development; do not use them yet.

## Usage

See [`examples/main.tf`](examples/main.tf) for a complete, runnable example.

```hcl
module "audit_logs_destination" {
  source = "git::https://github.com/sourcegraph/cloud-audit-logs-destination-setup.git?ref=v0.1.0"

  bucket_name            = "acme-audit-logs"
  gke_cluster_issuer_url = "<provided by Sourcegraph>"
  collector_ksa_sub      = "<provided by Sourcegraph>"
}
```

The IAM role and policy names default to `bucket_name`; set `resource_prefix`
only if you need to override the derived name. Provider config (region, profile)
is inherited from the caller.

## Inputs

| Name | Description | Required |
|---|---|---|
| `bucket_name` | Name of the S3 bucket that will receive the audit-log objects. | yes |
| `gke_cluster_issuer_url` | Provided by Sourcegraph. | yes |
| `collector_ksa_sub` | Provided by Sourcegraph. | yes |
| `resource_prefix` | Prefix for the IAM role + policy names. Defaults to `bucket_name`. | no |

## Outputs

| Name | Description |
|---|---|
| `sourcegraph_audit_role_arn` | Role ARN the collector assumes — report back to your Sourcegraph contact. |
| `sourcegraph_audit_bucket_name` | Destination bucket name. |
| `sourcegraph_audit_oidc_provider_arn` | ARN of the IAM OIDC provider created for the collector. |

Hand the role ARN and bucket name back to your Sourcegraph contact (phase 2 of
the enablement).
