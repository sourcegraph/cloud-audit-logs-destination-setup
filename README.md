# Cloud Audit Logs Destination Setup

Customer-side AWS resources that grant a Sourcegraph audit-log (OTel) collector
write access to an S3 bucket.

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

See [`examples/main.tf`](examples/main.tf) for a complete, runnable example.

```hcl
module "audit_logs_destination" {
  source = "git::https://github.com/sourcegraph/cloud-audit-logs-destination-setup.git?ref=v2.0.0"

  bucket_name = "acme-audit-logs"

  collectors = {
    "src-a1b2c3" = "<provided by Sourcegraph>"
  }
}
```

Keys are your Sourcegraph instance IDs, values the numeric unique ID of each
collector's GCP service account — both provided by Sourcegraph. The instance ID
becomes an IAM name segment (`<prefix>-<id>-collector`).

Each role gets write access to the whole bucket. The collector writes its objects
under a per-instance `src-<id>/` prefix, so instances sharing a bucket stay
separated by object key.

IAM names derive from `bucket_name` plus the collector key; set
`resource_prefix` only to override. Provider config (region, profile) is
inherited from the caller.

To send several Sourcegraph instances to the same bucket, add an entry per
instance — each gets its own role. Use one module instance per bucket: the module creates the bucket and owns its versioning,
encryption and public-access configuration, so pointing a second module instance
(or a second Terraform state) at the same `bucket_name` either fails on
`CreateBucket` or silently fights the first on every apply.

## Inputs

| Name | Description | Required |
|---|---|---|
| `bucket_name` | Name of the S3 bucket that will receive the audit-log objects. | yes |
| `collectors` | Map of Sourcegraph instance ID => numeric GCP service-account unique ID, matched as both `accounts.google.com:aud` and `:sub`. One IAM role per entry. Provided by Sourcegraph. | yes |
| `resource_prefix` | Prefix for the IAM role + policy names. Defaults to `bucket_name`. | no |
| `sourcegraph_audit_audience` | Audience (`:oaud`) the Sourcegraph token requests. Defaults to `sourcegraph-otel-audit-aws`. | no |

## Outputs

| Name | Description |
|---|---|
| `sourcegraph_audit_role_arns` | Map of instance ID => role ARN — report back to your Sourcegraph contact. |
| `sourcegraph_audit_bucket_name` | Destination bucket name. |

Hand the role ARNs and bucket name back to your Sourcegraph contact (phase 2 of
the enablement).
