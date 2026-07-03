# Cloud Audit Logs Destination Setup

Customer-side AWS resources that grant one Sourcegraph audit-log (OTel)
collector write access to an S3 bucket. One module instance = one collector →
one bucket.

Creates: the destination S3 bucket (versioned, KMS-encrypted, public access
blocked), a web-identity IAM role, and a write-only S3 policy the collector
assumes.

## Federation model

Google service account. The collector's refresher sidecar presents a
GSA-signed `accounts.google.com` ID token, so the role's trust policy keys only
on the Sourcegraph collector GSA (its numeric unique ID). Both
`accounts.google.com:aud` and `:sub` match that unique ID (Google sets
`aud == sub == uniqueId`); `:oaud` matches the audience constant
(`sourcegraph_audit_audience`).

There is no per-instance OIDC provider and no thumbprint to manage.

## Usage

```hcl
module "my_collector" {
  source = "git::https://github.com/sourcegraph/cloud-audit-logs-destination-setup.git?ref=main"

  bucket_name             = "acme-audit-logs"
  collector_gsa_unique_id = "115713869472664437675"
}
```

The IAM role and policy names default to `bucket_name`, which is unique per
collector, so two instances in one account never collide — no `resource_prefix`
needed. Set `resource_prefix` only to override the derived name. Provider config
(region, profile) is inherited from the caller.

## Inputs

| Name | Description | Required |
|---|---|---|
| `bucket_name` | Name of the S3 bucket that will receive the audit-log objects. | yes |
| `collector_gsa_unique_id` | Numeric unique ID of the Sourcegraph collector GCP service account, matched as both `accounts.google.com:aud` and `:sub`. Provided by Sourcegraph. | yes |
| `resource_prefix` | Prefix for the IAM role + policy names. Defaults to `bucket_name`. | no |
| `sourcegraph_audit_audience` | Audience (`:oaud`) the Sourcegraph token requests. Defaults to `sourcegraph-otel-audit-aws`. | no |

## Outputs

| Name | Description |
|---|---|
| `sourcegraph_audit_role_arn` | Role ARN the collector assumes — report back to your Sourcegraph contact. |
| `sourcegraph_audit_bucket_name` | Destination bucket name. |

Hand the role ARN and bucket name back to your Sourcegraph contact (phase 2 of
the enablement).
