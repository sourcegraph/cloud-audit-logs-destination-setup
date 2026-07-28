variable "bucket_name" {
  description = "Name of the GCS bucket that will receive the audit-log objects."
  type        = string
}

variable "location" {
  description = "Location of the GCS bucket (e.g. US, EU, us-central1)."
  type        = string
}

variable "collectors" {
  description = "Sourcegraph instance ID => the collector's GCP service-account email. GCS binds the GSA directly, so this is the email, not the numeric unique ID the AWS module takes. One pair of bucket IAM bindings per entry. Provided by Sourcegraph."
  type        = map(string)

  validation {
    condition     = length(var.collectors) > 0
    error_message = "At least one collector is required."
  }

  validation {
    condition     = alltrue([for k, _ in var.collectors : can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]*$", k))])
    error_message = "Instance IDs must start alphanumeric and contain only alphanumerics, dashes or underscores."
  }

  validation {
    condition     = alltrue([for email in values(var.collectors) : can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_.]*@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", email))])
    error_message = "Each collector value must be the collector GSA email (<name>@<project>.iam.gserviceaccount.com), not a numeric unique ID."
  }
}
