# Operations

<!-- markdownlint-disable MD013 -->

Probe `/health`, inspect application logs and verify that both claims are bound. Back up workspace and projects before upgrades. Use Recreate downtime because concurrent writers are unsupported.

If a restored workspace contains root-owned mode-0600 files, repair ownership to `10001:10001` using an audited administrative workflow before starting the Pod. Do not grant the long-running container CHOWN, SETUID or SETGID merely to repair a legacy backup.

The chart pins amd64 scheduling because upstream does not publish an arm64 container image.

After rotating `auth.existingSecret`, restart the Deployment so the process reads the new environment value. The
contract checksum changes only when Helm values change; ExternalSecret refreshes do not re-render the Deployment.
Install a Secret reloader if automatic rotation rollouts are required.

The optional PDB uses `minAvailable: 1`. On a single replica this blocks voluntary eviction and can prevent a node
drain from completing. Leave it disabled unless preserving availability is more important than unattended drains.
