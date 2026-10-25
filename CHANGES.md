# Changes from the pasted configuration

- Removed both GCP workload firewall rules for IPsec transport, including unrestricted ingress. The replacement permits ICMP from the AWS VPC to tagged test workloads only. Add application ports deliberately.
- Kept VGW vpc_id attachment; removed the duplicate attachment resource.
- Added a private subnet on each side, a dedicated AWS workload route table, its association, and VGW propagation.
- Advertise the actual GCP subnet rather than a nonexistent /16 aggregate and ALL_SUBNETS together.
- Removed unused reserved addresses and the machine-specific credential path. Use AWS credential chain, GCP ADC, and VAULT_ADDR/VAULT_TOKEN.
- Bounded Google provider to 6.28 patches and generated a provider lock file. AWS remains on major 5 to avoid mixing a major upgrade into the network cleanup.
- Replaced GCP tunnel/interface/peer repetition with a map and for_each. Optional legacy address mappings are stored under migration/ and are excluded from the active fresh-deployment configuration. AWS connection blocks retain their original addresses and explicit tunnel crypto.
- Four Vault KV v2 paths, one psk field each; each AWS/GCP tunnel pair uses the same unique key. No real secrets in the public configuration.
- Optional private test VMs with bounded boot-time ping loops in each direction, no public IPs, encrypted AWS root disk and IMDSv2.
- Per-tunnel CloudWatch alarms and a GCP tunnel alert. Notification destination IDs must be supplied for delivery.
- Disabled-BGP-peer variable supports a controlled route failover exercise. This tests route withdrawal, not a physical IPsec/interface outage.
- Encrypted, locking S3 backend template. Bootstrap the bucket/KMS/IAM/versioning separately; template is not active until configured.

## Deployment status
The fresh lab was deployed, bidirectional private-IP pings and both BGP interface-withdrawal scenarios passed, and a genuine console-and-terminal failover video was recorded. See TEST-RESULTS.md for evidence and limits. The tunnel-logging and temporary-identity additions were applied and checked; see the report for the distinction between configured AWS logging and observed event delivery.

Validation also corrected the original AWS integrity algorithm spelling from SHA256 to SHA2-256.

## Further requested changes

- Explicit encrypted JSON diagnostic logging on all four AWS tunnels; GCP HA VPN diagnostics already active, with a computed tunnel-ID query output.
- Separate bootstrap/identity/identity.tf and bootstrap/vault/vault.tf roots. No IAM access-key or GCP service-account-key resources.
- One-hour AWS STS role sessions, mandatory GCP service-account impersonation, and one-hour read-only Vault IAM tokens for normal deployments.
- Vault PSK bootstrap uses ephemeral generation and write-only inputs; ordinary VPN arguments still require protected network state.
- A permission boundary caps any flow-log roles the deployment identity can create/manage.
