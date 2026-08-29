# Persistence and backup

Matterbridge state is inseparable from its commissioned Matter identity. Keep
`persistence.enabled=true` for every real installation.

The chart mounts one volume at `/data`, containing plugins, plugin configuration,
Matter fabrics, certificates and application storage. The default PVC is 2 GiB,
ReadWriteOnce and retained after uninstall.

## Consistent backup

Stop the StatefulSet before copying files or taking a non-atomic backup:

```bash
MATTERBRIDGE_NAMESPACE=matterbridge
MATTERBRIDGE_STATEFULSET=$(kubectl get statefulset \
  -n "$MATTERBRIDGE_NAMESPACE" \
  -l app.kubernetes.io/name=matterbridge \
  -o jsonpath='{.items[0].metadata.name}')
kubectl scale -n "$MATTERBRIDGE_NAMESPACE" \
  statefulset/"$MATTERBRIDGE_STATEFULSET" --replicas=0
kubectl wait -n "$MATTERBRIDGE_NAMESPACE" \
  --for=delete pod -l app.kubernetes.io/name=matterbridge --timeout=120s
# Create and verify the PVC snapshot or backup.
kubectl scale -n "$MATTERBRIDGE_NAMESPACE" \
  statefulset/"$MATTERBRIDGE_STATEFULSET" --replicas=1
kubectl rollout status -n "$MATTERBRIDGE_NAMESPACE" \
  statefulset/"$MATTERBRIDGE_STATEFULSET" --timeout=300s
```

CSI snapshots that are atomic at the filesystem layer may reduce downtime, but
operators should still follow their storage provider's application-consistency
guidance. Test restore into an isolated namespace before relying on the backup.

## Existing claims

Set `persistence.existingClaim` to reuse a pre-created PVC. The claim must be in
the release namespace and writable by UID/GID 1000. The chart never deletes an
existing claim.

## Restore

Restore all `/data` content together, then start exactly one Matterbridge pod.
Do not copy only plugin configuration or only Matter storage; partial restores
can break fabric identity and force recommissioning.
