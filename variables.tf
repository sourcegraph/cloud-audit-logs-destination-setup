variable "sourcegraph_audit_audience" {
  description = "Audience the Sourcegraph projected service-account token requests. null = default."
  type        = string
  default     = null
}

variable "bucket_name" {
  description = "Name of the S3 bucket that will receive the audit-log objects."
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for the IAM role + policy names. null = derive from bucket_name (unique per collector)."
  type        = string
  default     = null
}

variable "collector_gsa_unique_id" {
  description = "Numeric unique ID of the Sourcegraph collector GCP service account. Matched as both accounts.google.com:aud and :sub in the role trust. Provided by Sourcegraph."
  type        = string
}
