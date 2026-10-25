param(
  [Parameter(Mandatory=$true)][string]$AwsRoleArn,
  [Parameter(Mandatory=$true)][string]$GcpServiceAccount,
  [Parameter(Mandatory=$true)][string]$VaultAddress,
  [string]$VaultAuthMount='vpn-aws',
  [string]$VaultRole='vpn-terraform',
  [string]$AwsRegion='us-east-1',
  [string]$AwsSourceProfile=''
)
$ErrorActionPreference='Stop'
# Dot-source from the shell that will run Terraform; credentials stay in memory.
# The source AWS sign-in may be SSO or the explicitly chosen lab bootstrap identity.
$stsArgs=@('sts','assume-role','--role-arn',$AwsRoleArn,'--role-session-name','vpn-terraform','--duration-seconds','3600','--output','json')
if ($AwsSourceProfile) { $stsArgs=@('--profile',$AwsSourceProfile)+$stsArgs }
$session=aws @stsArgs | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Could not obtain the one-hour AWS STS session' }
$env:AWS_ACCESS_KEY_ID=$session.Credentials.AccessKeyId
$env:AWS_SECRET_ACCESS_KEY=$session.Credentials.SecretAccessKey
$env:AWS_SESSION_TOKEN=$session.Credentials.SessionToken
$env:AWS_REGION=$AwsRegion
$env:AWS_DEFAULT_REGION=$AwsRegion
# Source OAuth token is short-lived. The Google provider below must impersonate
# the configured deployment service account; it never loads a JSON private key.
$env:GOOGLE_OAUTH_ACCESS_TOKEN=(gcloud auth print-access-token --quiet)
if ($LASTEXITCODE -ne 0) { throw 'Could not obtain the source Google OAuth token' }
$env:TF_VAR_gcp_deployment_service_account=$GcpServiceAccount
$env:VAULT_ADDR=$VaultAddress
# The IAM login signs GetCallerIdentity using the temporary STS session above.
# Do not persist this token to the Vault token helper or write it to a tfvars file.
Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue
$env:VAULT_TOKEN=(vault login -no-store -token-only -method=aws "-path=$VaultAuthMount" "role=$VaultRole" header_value=aws-gcp-vpn-lab "region=$AwsRegion")
if ($LASTEXITCODE -ne 0) { throw 'Vault IAM login failed' }
Write-Output "Temporary credentials ready: AWS STS expires $($session.Credentials.Expiration); Google impersonation; Vault IAM token (maximum one hour)."
