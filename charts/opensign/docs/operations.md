# OpenSign operations

## Day-two checks

```bash
kubectl -n opensign get deploy,pod,svc,pvc
kubectl -n opensign get events --sort-by=.lastTimestamp
kubectl -n opensign logs deploy/opensign-opensign-backend
kubectl -n opensign logs deploy/opensign-opensign-frontend
```

Confirm both Services have endpoints, the frontend loads, the API responds, and
pods do not restart. Treat repeated migration, MongoDB, signing, or upload
errors as rollout failures.

## Backup

Capture a consistent set containing MongoDB, the local PVC or S3 bucket, the
Parse master key, the PKCS#12 certificate, and integration credentials. Encrypt
backup artifacts and document retention and restoration ownership.

## Restore test

1. Create an isolated namespace.
2. Restore secrets and the document store.
3. Restore MongoDB.
4. Install the chart with the original image digests and public URLs adjusted.
5. Verify login, an existing template, document download, a new signature, and
   outbound email.
6. Record recovery time and remove the isolated environment.

## Upgrade

Read upstream release notes and back up state. Re-verify official image
manifests, change both digests together when the release requires it, and run
the full chart validation. The backend upgrade causes a brief interruption due
to `Recreate`; do not override that strategy without upstream migration safety
evidence.

Changing `containerPorts.frontend` or `containerPorts.backend` changes the real
Node.js listener through `PORT`. Services and NetworkPolicies follow the named
ports automatically. Use a value from 1024 through 65535; the non-root
containers do not receive `NET_BIND_SERVICE`. Treat a listener change as an
application rollout and verify both browser and API paths before production
traffic resumes.

## Certificate rotation

Replace the PFX and passphrase together, restart the backend, sign a disposable
document, and retain the previous certificate according to the organization's
verification and retention requirements.
