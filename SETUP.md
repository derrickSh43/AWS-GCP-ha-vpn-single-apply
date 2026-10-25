# Setup

## Before you start

Install Terraform 1.11+, AWS CLI, Google Cloud CLI, and Vault CLI. You need an AWS account, a GCP project with billing and the Compute, IAM, Monitoring, Logging, Service Usage, and Cloud Resource Manager APIs enabled, and a running Vault server.

Create a private, encrypted, versioned S3 bucket for Terraform state. Each root has a `backend.tf.example`: copy it to `backend.tf` and fill in the bucket, region, and encryption-key settings. Keep the three state keys distinct.

## 1. Create deployment identities

Sign in to AWS with an identity allowed to create the deployment role, and sign in to GCP:

```powershell
gcloud auth login
$env:GOOGLE_OAUTH_ACCESS_TOKEN = gcloud auth print-access-token
Copy-Item bootstrap/identity/terraform.tfvars.example bootstrap/identity/terraform.tfvars
```

Fill in the project, source AWS principal ARN, source GCP principal (for example `user:YOUR_EMAIL`), and state bucket. Then run:

```powershell
terraform -chdir=bootstrap/identity init
terraform -chdir=bootstrap/identity apply
```

Save the role ARN, GCP service-account email, and flow-log boundary ARN from the outputs.

## 2. Configure Vault

Set `VAULT_ADDR` and `VAULT_TOKEN` in your shell using your Vault address and an administrator login. Copy `bootstrap/vault/terraform.tfvars.example` to `terraform.tfvars` in that directory and set the deployment role ARN from step 1.

```powershell
terraform -chdir=bootstrap/vault init
terraform -chdir=bootstrap/vault apply
```

This creates four independent tunnel keys and the IAM login policy. Terraform configures your existing Vault server; it does not install one.

## 3. Deploy the VPN

Copy the root `terraform.tfvars.example` to `terraform.tfvars`. Set your project, deployment service account, and flow-log boundary ARN. Keep the Vault mount and prefix consistent with step 2.

From a fresh PowerShell session with your AWS source profile and GCP login available:

```powershell
. ./scripts/Use-TemporaryCredentials.ps1 `
  -AwsRoleArn 'YOUR_ROLE_ARN' `
  -GcpServiceAccount 'YOUR_SERVICE_ACCOUNT_EMAIL' `
  -VaultAddress 'YOUR_VAULT_URL' `
  -AwsSourceProfile 'YOUR_AWS_PROFILE'

terraform init
terraform plan '-out=vpn.tfplan'
terraform apply vpn.tfplan
```

The network deploys in one apply after bootstrap. The public code creates the VPN and subnets; it does not create workload VMs. GCP workloads tagged `vpn-access` allow ICMP from the AWS VPC; add application rules as needed. Set `aws_alarm_action_arns` and `gcp_notification_channels` if you want alert delivery.

Cloud API credentials are temporary; tunnel PSKs remain in protected network state and saved plans. Keep real variables, credentials, state, and plans out of Git.

## Remove the VPN

With credentials refreshed and Vault available, run `terraform destroy` from the root. Identity and Vault bootstrap resources remain separate. VPN resources incur charges while running.
