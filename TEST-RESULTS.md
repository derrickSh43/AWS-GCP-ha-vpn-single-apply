# Deployment and runtime verification

Tested October 24, 2026 (America/Guatemala); UTC observations fall on October 25.

## Deployment

The initial fresh network deployment completed in one Terraform apply: 36 resources created. The second AWS VPN connection took 18 minutes 40 seconds to provision. A subsequent refinement apply added five logging/default-security-group resources, enabled GCP subnet logging, and replaced the two disposable test VMs to correct Linux script line endings and enable EC2 monitoring/EBS optimization. These corrections are included in the final published source. The final network root has 48 managed resources. Separate identity and Vault bootstrap roots manage 11 and 9 resources respectively (68 total), plus the separately bootstrapped state bucket. The later logging/authentication apply added seven network resources and updated three existing resources. Both disposable VMs were subsequently refreshed for the live recording.

The final combined source has not been destroyed and redeployed from scratch as a separate single-apply experiment. The network's single-apply dependency graph was exercised successfully; the complete final configuration is validated and reconciled against the running lab.

## Observed results

| Scenario | BGP peers UP | AWS to GCP latest complete sample | GCP to AWS latest complete sample |
|---|---:|---|---|
| Baseline | 4 / 4 | 3 / 3 replies | 3 / 3 replies |
| Interface 0 BGP peers disabled | 2 / 4 | 3 / 3 replies | 3 / 3 replies |
| Interface 0 peers restored | 4 / 4 | 3 / 3 replies | 3 / 3 replies |
| Interface 1 BGP peers disabled | 2 / 4 | 3 / 3 replies | 3 / 3 replies |

The AWS workload route table contained an active propagated route to 10.240.1.0/24 through the VGW. All four GCP BGP peers learned an AWS route in the baseline. AWS VPC flow logging reported ACTIVE / SUCCESS. All four CloudWatch tunnel alarms were OK before failover testing.

This test withdrew BGP peers with Terraform enable flags. It did not deliberately disable IPsec transport or simulate physical gateway hardware failure. Console samples establish observed connectivity in both directions through either surviving pair; they are not continuous packet capture, exact convergence timing, or proof of zero packet loss during failover. Initial VM boot samples included loss before both hosts were ready.

## Crypto evidence

GCP VPN logs recorded these selected proposals:

```
IKE:AES_CBC_256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_4096
ESP:AES_CBC_256/HMAC_SHA2_256_128/NO_EXT_SEQ
```

These establish observed IKE/ESP encryption and integrity selection. DH group 16 (4096-bit MODP) is present in the recorded IKE proposal; phase-two group 16 is configured, but this initial-child-SA log is not independent proof of phase-two PFS during a later rekey.

## Local quality checks

- terraform fmt: passed.
- terraform validate: passed, with the documented Vault legacy-data-source deprecation warning.
- TFLint: passed.
- Checkov 3.3.30: 126 passed, zero failed, three documented lab exceptions, zero parsing errors.
- A GitHub Actions workflow is provided; no hosted GitHub CI run or public repository publication is claimed.

Notifications were not delivery-tested: destination lists are empty. GCP and AWS alert resources exist, but no claim is made that an email, SMS, or other external notification was sent.

## Temporary authentication and tunnel diagnostics

The running network was applied using an AWS STS assumed role, Google service-account impersonation, and a non-root Vault AWS-IAM login token with a one-hour maximum lifetime. The user-selected source AWS identity remains an existing IAM user; this lab does not claim an entirely keyless source login chain. No new static AWS or Google deployment keys were created.

All four AWS tunnel options report JSON logging enabled, and all four encrypted CloudWatch log groups have streams. The verification query did not observe AWS log events at that point; enabled configuration and streams are not proof of event delivery. GCP diagnostic log entries were observed. Vault bootstrap state was checked against the four actual PSKs and temporary credential values: none were present. The network state still contains provider-required VPN secrets and must remain protected.

## Video

The console-and-terminal recording is genuine screen capture, with approximately one-third terminal and two-thirds cloud console. It shows the two-peer BGP withdrawal result, real private-VM samples, the restore command, and recovery. Waiting periods may be shortened in the shareable edit. It supersedes the earlier diagram-based telemetry replay.

Detailed sanitized samples and cloud-state observation times are in test-results.json. The lab network was subsequently destroyed at the user's request: Terraform reported 48 resources destroyed and no managed network-root resources remaining. State backend and identity/Vault bootstrap were retained for a fresh user-run apply. The diagnostic KMS key is scheduled for deletion after its configured seven-day waiting period.
