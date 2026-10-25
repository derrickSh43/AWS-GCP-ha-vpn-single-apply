# Console and terminal failover recording

This approximately 61-second video is actual screen capture, composed with one-third live terminal and two-thirds cloud console. It shows the disabled BGP pair and private-VM samples, the Terraform restore command/apply, GCP recovery to four established sessions, and AWS recovery with logging enabled. It starts after the withdrawal apply; that initial command is not included in this edit. Waiting periods are cut and the restore-apply segment is labeled 3x playback.

The experiment changes BGP enable flags; it does not intentionally cut IPsec transport. VM ping output is read from cloud console/serial logs and may lag the current tunnel state. The individual three-packet samples do not measure uninterrupted reachability or exact convergence time. AWS tunnel telemetry also lagged GCP BGP recovery; the final shot follows a fresh AWS refresh.

The earlier diagram-based replay is superseded by this recording. This public copy permanently masks deployment identifiers, endpoint IPs, local paths, and resource details in the video pixels. Some terminal apply output is hidden to avoid exposing project/resource identifiers. The real tunnel/BGP states, restore command, and ping samples remain visible. No cloud API credentials or Vault keys are displayed. The unredacted original stays in the private local workspace.

Small bottom captions explain the visible events as they occur. The SRT file contains the same timed captions for reuse.

