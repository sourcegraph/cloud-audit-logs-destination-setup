# Cloud Audit Logs Destination Setup

Customer-side resources that grant a Sourcegraph audit-log (OTel) collector
write access to a bucket you own.

A customer is only ever one cloud, so each has its own self-contained module —
pick one and you only ever configure that provider:

| Cloud | Module source | Example |
|---|---|---|
| AWS | `?ref=v2.1.0` (repo root) | [`examples/aws`](examples/aws/main.tf) |
| GCP | `//gcp?ref=v2.1.0` | [`examples/gcp`](examples/gcp/main.tf) |

AWS creates an S3 bucket (versioned, KMS-encrypted, public access blocked) plus a
web-identity IAM role and write-only policy per collector. GCP creates a GCS
bucket (versioned, uniform bucket-level access, public access prevention) plus
two bucket-scoped IAM bindings per collector GSA.

The `collectors` map value differs: a numeric GSA unique ID for AWS, a GSA email
for GCP. Both reject the wrong shape at plan time.

## Federation model

### AWS

Google service account. The collector's refresher sidecar presents a
GSA-signed `accounts.google.com` ID token, so the role's trust policy keys only
on the Sourcegraph collector GSA (its numeric unique ID). Both
`accounts.google.com:aud` and `:sub` match that unique ID (Google sets
`aud == sub == uniqueId`); `:oaud` matches the audience constant
(`sourcegraph_audit_audience`).

There is no per-instance OIDC provider and no thumbprint to manage.

### GCP

There is no federation. The collector's GSA authenticates to Google directly, so
access is just a pair of bucket-scoped IAM bindings on that GSA's email — no
role, no trust policy, no OIDC provider, and no unique ID. Two roles are needed:

| Role | Why |
|---|---|
| `roles/storage.objectCreator` | Write the audit-log objects (the `s3:PutObject` equivalent). |
| `roles/storage.legacyBucketReader` | Grants `storage.buckets.get`. The exporter sets `reuse_if_exists`, so it probes the bucket before the first write. Despite the name this is the canonical predefined role for "read bucket metadata only" — nothing narrower grants `buckets.get`. |

Bindings use `google_storage_bucket_iam_member` (additive), so any unrelated
bindings already on your bucket are left untouched.

## Usage

### AWS

```hcl
provider "aws" {
  region = "us-east-1"
}

module "audit_logs_destination" {
  source = "git::https://github.com/sourcegraph/cloud-audit-logs-destination-setup.git?ref=v2.1.0"

  bucket_name = "acme-audit-logs"

  collectors = {
    "src-a1b2c3" = "<numeric GSA unique ID, provided by Sourcegraph>"
  }
}
```

Full example: [`examples/aws/main.tf`](examples/aws/main.tf).

### GCP

```hcl
provider "google" {
  project = "acme-prod"
  region  = "us-central1"
}

module "audit_logs_destination" {
  source = "git::https://github.com/sourcegraph/cloud-audit-logs-destination-setup.git//gcp?ref=v2.1.0"

  bucket_name = "acme-audit-logs"
  location    = "US"

  collectors = {
    "src-a1b2c3" = "<collector GSA email, provided by Sourcegraph>"
  }
}
```

Full example: [`examples/gcp/main.tf`](examples/gcp/main.tf).

To send several Sourcegraph instances to the same bucket, add an entry per
instance. Use one module instance per bucket: the module creates the bucket and
owns its versioning, encryption and public-access configuration, so pointing a
second module instance (or a second Terraform state) at the same `bucket_name`
either fails on create or silently fights the first on every apply.

## Inputs

### AWS

| Name | Description | Required |
|---|---|---|
| `bucket_name` | Name of the S3 bucket that will receive the audit-log objects. | yes |
| `collectors` | Map of Sourcegraph instance ID => numeric GCP service-account unique ID. Provided by Sourcegraph. | yes |
| `resource_prefix` | Prefix for the IAM role + policy names. Defaults to `bucket_name`. | no |
| `sourcegraph_audit_audience` | Audience (`:oaud`) the Sourcegraph token requests. Defaults to `sourcegraph-otel-audit-aws`. | no |

### GCP

| Name | Description | Required |
|---|---|---|
| `bucket_name` | Name of the GCS bucket that will receive the audit-log objects. | yes |
| `location` | GCS bucket location (e.g. `US`, `EU`, `us-central1`). | yes |
| `collectors` | Map of Sourcegraph instance ID => collector GSA email. Provided by Sourcegraph. | yes |

## Outputs

| Name | Module | Description |
|---|---|---|
| `sourcegraph_audit_bucket_name` | both | Destination bucket name. |
| `sourcegraph_audit_role_arns` | AWS | Map of instance ID => role ARN. |
| `sourcegraph_audit_gcs_bindings` | GCP | Map of instance ID => GSA member + granted roles. |

Hand the bucket name back to your Sourcegraph contact (phase 2 of the
enablement) — plus the role ARNs on AWS. On GCP the GSA is Sourcegraph-side, so
the bucket name and confirmation that the bindings exist are the whole artifact.

## Upgrading from v2.0.0 (AWS callers)

Nothing to do. The AWS module is unchanged: same inputs, same outputs, same
resource addresses and IAM names. GCP support lives in a separate `//gcp`
submodule, so it adds no provider requirement and no state migration here.
