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

variable "collectors" {
  description = "Sourcegraph instance ID => numeric unique ID of the collector's GCP service account. One IAM role per entry, each granted write access to the bucket. Provided by Sourcegraph."
  type        = map(string)

  validation {
    condition     = length(var.collectors) > 0
    error_message = "At least one collector is required."
  }

  validation {
    condition     = alltrue([for k, _ in var.collectors : can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]*$", k))])
    error_message = "Instance IDs must start alphanumeric and contain only alphanumerics, dashes or underscores (they appear in IAM names)."
  }

  validation {
    condition     = alltrue([for id in values(var.collectors) : can(regex("^[0-9]+$", id))])
    error_message = "Collector GSA unique ID must be numeric, not an email address."
  }
}
