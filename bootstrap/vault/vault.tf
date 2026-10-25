terraform {
  required_version = ">= 1.11, < 2.0"
  required_providers {
    vault  = { source = "hashicorp/vault", version = "~> 5.13.0" }
    random = { source = "hashicorp/random", version = "~> 3.7" }
  }
}
# Bootstrap with an existing Vault administrator login, supplied in the environment.
# That admin token is never used by the network deployment provider.
provider "vault" { skip_child_token = true }
variable "vault_mount" {
  type    = string
  default = "vpn"
}
variable "vault_prefix" {
  type    = string
  default = "aws-gcp-vpn"
}
variable "aws_deployment_role_arn" { type = string }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "psk_revision" {
  type    = number
  default = 1
}
locals { tunnels = toset(["tunnel0", "tunnel1", "tunnel2", "tunnel3"]) }
resource "vault_mount" "vpn" {
  path        = var.vault_mount
  type        = "kv"
  options     = { version = "2" }
  description = "Independent IPsec keys for the AWS / GCP lab"
}
ephemeral "random_password" "psk" {
  for_each = local.tunnels
  length   = 63
  special  = false
}
resource "vault_kv_secret_v2" "tunnel" {
  for_each = local.tunnels
  mount    = vault_mount.vpn.path
  name     = "${var.vault_prefix}/${each.key}"
  data_json_wo = jsonencode({
    psk = "A${ephemeral.random_password.psk[each.key].result}"
  })
  data_json_wo_version = var.psk_revision
}
resource "vault_policy" "read_tunnel_keys" {
  name   = "aws-gcp-vpn-read-tunnel-keys"
  policy = <<-POLICY
    path "${vault_mount.vpn.path}/data/${var.vault_prefix}/*" {
      capabilities = ["read"]
    }
    path "${vault_mount.vpn.path}/metadata/${var.vault_prefix}/*" {
      capabilities = ["read", "list"]
    }
  POLICY
}
resource "vault_auth_backend" "aws" {
  type = "aws"
  path = "vpn-aws"
}
resource "vault_aws_auth_backend_client" "iam" {
  backend                    = vault_auth_backend.aws.path
  iam_server_id_header_value = "aws-gcp-vpn-lab"
  sts_region                 = var.aws_region
  sts_endpoint               = "https://sts.${var.aws_region}.amazonaws.com"
  # No AWS access_key / secret_key: signed IAM login is verified through STS.
}
resource "vault_aws_auth_backend_role" "deployment" {
  depends_on               = [vault_aws_auth_backend_client.iam]
  backend                  = vault_auth_backend.aws.path
  role                     = "vpn-terraform"
  auth_type                = "iam"
  bound_iam_principal_arns = [var.aws_deployment_role_arn]
  resolve_aws_unique_ids   = false
  token_policies           = [vault_policy.read_tunnel_keys.name]
  token_ttl                = 3600
  token_max_ttl            = 3600
  token_explicit_max_ttl   = 3600
}
output "vault_aws_auth_path" { value = vault_auth_backend.aws.path }
output "vault_aws_auth_role" { value = vault_aws_auth_backend_role.deployment.role }
