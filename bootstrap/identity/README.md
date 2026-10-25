# Deployment identity bootstrap

Apply this separate root once with an authorized source identity. It provisions an AWS STS-assumable role (one-hour maximum), region-scoped network/logging/monitoring permissions, state-prefix access, and an IAM permission boundary on delegated flow-log roles. It also creates a GCP deployment service account, the required Sandbox-project roles, and a Token Creator binding for the authorized source user/principal.

It creates no IAM access keys and no service-account private keys. The role is a lab network administrator within the configured AWS region, with project-scoped GCP network/instance/security/monitoring roles. Review these permissions against your production requirements rather than treating them as a production permissions model.

Use a separate encrypted backend state key. Copy terraform.tfvars.example and replace the bootstrap principal identifiers and bucket/project placeholders. The provided network CI performs static checks; applying this bootstrap requires privileged credentials supplied outside Terraform source.

Copy the role ARN, flow-log boundary ARN and GCP service account email outputs into the network inputs. See ../../AUTHENTICATION.md for short-lived runtime authentication.
