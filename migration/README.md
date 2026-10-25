# Optional migration from the original resource names

Fresh deployments do not need these files. The active network configuration and the single-file version contain no migration blocks.

For an existing deployment that still uses the original individual GCP tunnel, router-interface and peer addresses, review `legacy-addresses.tf.example`. Copy it into that deployment root as `moved.tf` only when its `from` addresses match the existing state. The twelve mappings identify the same resources under the new `for_each` addresses; they do not move infrastructure between clouds.

Use the existing deployment backend and review the full plan. These mappings only cover GCP address changes; they do not resolve duplicate VGW attachment ownership or other infrastructure changes. Do not apply the fresh-deployment example against existing infrastructure without a migration review.
