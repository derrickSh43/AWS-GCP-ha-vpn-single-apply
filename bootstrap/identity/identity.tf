terraform {
  required_version = ">= 1.11, < 2.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    google = { source = "hashicorp/google", version = "~> 6.28.0" }
  }
}
provider "aws" { region = var.aws_region }
provider "google" { project = var.project_id }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project_id" { type = string }
variable "bootstrap_aws_principal_arn" { type = string }
variable "bootstrap_gcp_principal" { type = string }
variable "state_bucket_name" { type = string }
resource "aws_iam_role" "deployment" {
  name                 = "aws-gcp-vpn-deployer"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { AWS = var.bootstrap_aws_principal_arn }, Action = "sts:AssumeRole" }]
  })
}
data "aws_caller_identity" "current" {}
resource "aws_iam_policy" "flow_boundary" {
  name        = "aws-gcp-vpn-flow-log-boundary"
  description = "Upper permission limit for VPN lab flow-log delivery roles"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
      Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/aws-gcp-vpn-*:*"
    }]
  })
}
resource "aws_iam_role_policy" "deployment" {
  name = "vpn-lab-deployment"
  role = aws_iam_role.deployment.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RegionalNetworkAndTestHosts"
        Effect    = "Allow"
        Action    = ["ec2:Describe*", "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute", "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress", "ec2:CreateVpnGateway", "ec2:DeleteVpnGateway", "ec2:AttachVpnGateway", "ec2:DetachVpnGateway", "ec2:CreateCustomerGateway", "ec2:DeleteCustomerGateway", "ec2:CreateVpnConnection", "ec2:DeleteVpnConnection", "ec2:ModifyVpnConnectionOptions", "ec2:ModifyVpnTunnelOptions", "ec2:EnableVgwRoutePropagation", "ec2:DisableVgwRoutePropagation", "ec2:CreateTags", "ec2:DeleteTags", "ec2:RunInstances", "ec2:TerminateInstances", "ec2:ModifyInstanceAttribute", "ec2:MonitorInstances", "ec2:UnmonitorInstances", "ec2:GetConsoleOutput", "ec2:CreateFlowLogs", "ec2:DeleteFlowLogs", "ec2:CreateVolume", "ec2:DeleteVolume"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } }
      },
      {
        Sid       = "RegionalLogAndAlarmManagement"
        Effect    = "Allow"
        Action    = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:GetLogEvents", "logs:FilterLogEvents", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy", "logs:AssociateKmsKey", "logs:DisassociateKmsKey", "logs:ListTagsForResource", "logs:TagResource", "logs:UntagResource", "logs:PutResourcePolicy", "logs:DescribeResourcePolicies", "logs:DeleteResourcePolicy", "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:ListLogDeliveries", "logs:UpdateLogDelivery", "logs:DeleteLogDelivery", "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms", "cloudwatch:ListTagsForResource", "cloudwatch:TagResource", "cloudwatch:UntagResource"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } }
      },
      {
        Sid       = "RegionalLogEncryptionKeyManagement"
        Effect    = "Allow"
        Action    = ["kms:CreateKey", "kms:DescribeKey", "kms:GetKeyPolicy", "kms:PutKeyPolicy", "kms:EnableKeyRotation", "kms:GetKeyRotationStatus", "kms:ListResourceTags", "kms:ListAliases", "kms:TagResource", "kms:UntagResource", "kms:CreateAlias", "kms:DeleteAlias", "kms:UpdateAlias", "kms:ScheduleKeyDeletion", "kms:Decrypt", "kms:GenerateDataKey"]
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } }
      },
      {
        Sid      = "FlowLogRoleOnly"
        Effect   = "Allow"
        Action   = ["iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:UntagRole", "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-gcp-vpn-flow-*"
      },
      {
        Sid       = "CreateBoundedFlowLogRoles"
        Effect    = "Allow"
        Action    = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
        Resource  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-gcp-vpn-flow-*"
        Condition = { StringEquals = { "iam:PermissionsBoundary" = aws_iam_policy.flow_boundary.arn } }
      },
      {
        Sid       = "PassOnlyFlowLogRole"
        Effect    = "Allow"
        Action    = ["iam:PassRole"]
        Resource  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-gcp-vpn-flow-*"
        Condition = { StringEquals = { "iam:PassedToService" = "vpc-flow-logs.amazonaws.com" } }
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.aws_region}::parameter/aws/service/ami-amazon-linux-latest/*"
      },
      {
        Sid      = "StateBucketMetadata"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = "arn:aws:s3:::${var.state_bucket_name}"
      },
      {
        Sid      = "StateAndLockObjectsOnly"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.state_bucket_name}/aws-gcp-ha-vpn/*"
      }
    ]
  })
}
resource "google_service_account" "deployment" {
  account_id   = "vpn-terraform-deployer"
  display_name = "VPN Terraform short-lived impersonated deployment identity"
}
resource "google_project_iam_member" "deployment" {
  for_each = toset(["roles/compute.networkAdmin", "roles/compute.securityAdmin", "roles/compute.instanceAdmin.v1", "roles/monitoring.editor", "roles/logging.viewer", "roles/serviceusage.serviceUsageConsumer"])
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.deployment.email}"
}
resource "google_service_account_iam_member" "impersonate" {
  service_account_id = google_service_account.deployment.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.bootstrap_gcp_principal
}
output "aws_deployment_role_arn" { value = aws_iam_role.deployment.arn }
output "gcp_deployment_service_account" { value = google_service_account.deployment.email }

output "flow_log_permissions_boundary_arn" { value = aws_iam_policy.flow_boundary.arn }
