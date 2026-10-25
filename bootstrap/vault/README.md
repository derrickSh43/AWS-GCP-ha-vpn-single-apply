# Vault bootstrap

This directory is a separate Terraform root; do not merge its resources/providers into the network root.

Prerequisites: an already-running Vault server, a bootstrap administrator login supplied via the environment, the deployment role ARN from ../identity, and an encrypted remote state backend configured for a distinct key. The lab server was a local development Vault process; Terraform configures its mount, secrets, policy and authentication, not the server executable or a production Vault cluster.

Copy terraform.tfvars.example, set the role ARN and desired KV mount/prefix, configure a backend, then run init, plan and apply. Fresh setup creates four random PSKs via ephemeral Random resources and write-only Vault secret arguments. It does not create or output an administrator token. Existing mounts require explicit import; this lab imported its preexisting test mount and supplied existing keys as an ephemeral environment input to preserve working tunnels.

Use AUTHENTICATION.md at the project root for the normal AWS IAM login flow. After bootstrap, network plans/applies use a one-hour read-only Vault token, not the bootstrap administrator token.

Changing psk_revision is a deliberate write/rotation operation. Coordinate it with both cloud endpoints and expect possible disruption. Do not put existing_tunnel_psks in any persistent tfvars file or plan artifact; it is an ephemeral input.
