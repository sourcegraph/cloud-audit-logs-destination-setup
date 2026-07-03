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

variable "gke_cluster_issuer_url" {
  description = "GKE cluster OIDC issuer URL the collector's projected token is issued by. Embeds the GCP project, location, and cluster; AWS registers an IAM OIDC provider for it. Provided by Sourcegraph."
  type        = string
}

variable "collector_ksa_sub" {
  description = "Collector projected-token `sub`: system:serviceaccount:<per-instance-namespace>:audit-log-stream-collector. The namespace is the instance's K8s namespace, not the GCP project. Provided by Sourcegraph."
  type        = string
}
