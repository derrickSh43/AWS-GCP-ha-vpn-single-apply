# Temporary deployment credentials

## What is temporary

Normal network deployment uses:

- AWS: STS AssumeRole credentials for `aws-gcp-vpn-deployer`, with a one-hour maximum session. All three session values stay in process environment variables. A VPC lifecycle precondition rejects a direct IAM-user deployment identity.
- GCP: the Google provider impersonates the required deployment service account from a short-lived source OAuth access token. No service-account key resource or JSON private-key file is used.
- Vault: AWS IAM login signed with the STS session returns a non-root, read-only token, capped at one hour. The provider sets `skip_child_token = true`; it does not require privileges to mint child tokens.

The chosen source AWS login for this lab remains the existing local IAM-user profile, as explicitly requested. That identity creates the role once and mints STS sessions afterward. Therefore the deployment credentials are temporary, but the entire source sign-in chain is not claimed to be keyless. Replace the source profile/trust with IAM Identity Center/SSO for that property. No existing source credentials were copied into the public source or removed from the machine.

The Google source login is the existing signed-in user OAuth session; cloud requests from the Terraform Google provider use the impersonated service account. Source-user authority is used once to create the service account, grant scoped project roles and permit impersonation.

## Separate one-time bootstraps

1. Secure the remote-state bucket (see README and backend.tf.example).
2. Apply `bootstrap/identity` using an authorized bootstrap identity. It creates the AWS role and region-scoped service permissions, a permission boundary for flow-log roles, and the GCP service account/role grants. It creates no AWS IAM access keys and no GCP service-account keys. AWS GetSessionToken without MFA cannot perform IAM changes; use the authorized source identity, an existing administrative assumed role, or MFA-authenticated bootstrap credentials.
3. Point `bootstrap/vault` at an already-running Vault server using an administrator login from the environment. Apply its separate `vault.tf`. It configures KV v2, four independent secrets, scoped read policy, AWS IAM auth and one-hour token limits. Administrator access is for this bootstrap only; it is not the normal deployment token.
4. Copy the bootstrap outputs into the network's real, ignored tfvars. Use separate encrypted state keys for identity, Vault and network roots.

The network is still a single apply after these prerequisites. Provider identities must exist before the network plan, so their creation is deliberately a separate bootstrap.

## Normal network session

From a fresh PowerShell session with the intended source AWS profile and GCP user login:

```powershell
. ./scripts/Use-TemporaryCredentials.ps1 -AwsRoleArn 'REPLACE_ME_ROLE_ARN' -GcpServiceAccount 'REPLACE_ME_SA_EMAIL' -VaultAddress 'https://REPLACE_ME_VAULT'
terraform init
terraform plan '-out=network.tfplan'
terraform apply network.tfplan
```

Do not print environment credentials or commit plans. The script does not save the Vault token to a token helper. Use a fresh source session to refresh credentials, rather than trying to assume the deployment role from itself. CI should federate its source identity with OIDC/SSO instead of storing the bootstrap user's keys in repository secrets; the supplied CI workflow runs credential-free static checks only.

## Vault and tunnel keys

Vault IAM auth binds the exact deployment role ARN with `resolve_aws_unique_ids = false`, allowing signed STS login validation without storing an AWS key on the Vault server. That means the binding is ARN-based rather than pinned to an IAM principal's immutable unique ID; production deployments may choose workload identity for Vault and immutable-ID resolution instead.

Fresh Vault bootstrap keys are generated with ephemeral Random provider resources and written through `data_json_wo`. No PSK value is intentionally stored in the Vault-bootstrap Terraform state. `psk_revision` controls deliberate key writes; leave it unchanged for routine runs. An optional ephemeral input preserves existing keys during adoption. Verify bootstrap state if adopting old resources that already stored secret payloads.

VPN PSKs are protocol secrets, not cloud API credentials: they remain stable per tunnel until coordinated rotation. The network's ordinary AWS/GCP VPN secret arguments still put PSKs in its protected Terraform state and saved plans. Temporary API credentials do not eliminate that state exposure.

The local development Vault used in this test listens only on loopback and loses data when stopped. It retains a private bootstrap admin credential for local administration; regular network operations do not read or use it. Use a durable, TLS-protected Vault service with normal administrator authentication outside this disposable lab.
