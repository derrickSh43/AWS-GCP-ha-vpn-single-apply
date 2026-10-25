variable "project_id" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "vault_mount" {
  type    = string
  default = "vpn"
}

variable "vault_prefix" {
  type    = string
  default = "aws-gcp-vpn"
}

variable "aws_subnet_cidr" {
  type    = string
  default = "10.230.1.0/24"
}

variable "gcp_subnet_cidr" {
  type    = string
  default = "10.240.1.0/24"
}

variable "disabled_bgp_peers" {
  type    = set(string)
  default = []
  validation {
    condition     = length(setsubtract(var.disabled_bgp_peers, toset(["tunnel0", "tunnel1", "tunnel2", "tunnel3"]))) == 0
    error_message = "Only tunnel0 through tunnel3 may be disabled."
  }
}

variable "aws_deployment_role_name" {
  description = "Deployment must run as an STS session for this IAM role."
  type        = string
  default     = "aws-gcp-vpn-deployer"
}
variable "gcp_deployment_service_account" {
  description = "Service account to impersonate using short-lived OAuth credentials; no service-account key file."
  type        = string
  validation {
    condition     = can(regex("@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.gcp_deployment_service_account))
    error_message = "A non-empty GCP service-account email is required; user-credential fallback is not allowed."
  }
}

variable "flow_log_permissions_boundary_arn" {
  description = "IAM permission ceiling created by the identity bootstrap for the flow-log delivery role."
  type        = string
}
