# Operations and two-factor authentication

## First login

Install first in paper and read-only mode. Watch logs and approve the mobile
two-factor request associated with the expected account:

```bash
kubectl -n ib-gateway logs deployment/ib-gateway --follow
kubectl -n ib-gateway get pods,svc,pvc
```

Do not infer successful authentication solely from the external `socat` port.
The chart readiness probe waits for the internal active Gateway listener.

## Session lifecycle

`gateway.autoRestartTime` defaults to `11:59 PM` in IBC syntax. A daily restart
can preserve a weekly session, but upstream and IBKR can still require manual
approval. `gateway.twoFactorTimeoutAction` and related values control what IBC
does when approval is not received.

Another login can replace this session. Keep `replicaCount: 1`; do not use a
rolling update, HPA, or a second release for the same credentials.

## Live trading change

Before selecting `gateway.tradingMode: live`:

1. Prove client connectivity and behavior against paper trading.
2. Confirm the release and account Secret point to the intended identity.
3. Keep `gateway.readOnlyApi: true` until write access is explicitly required.
4. Review `gateway.allowBlindTrading`; its safe default is false.
5. Restrict API clients through NetworkPolicy and private transport.

The chart does not implement order limits or trading-risk policy.

## Settings backup and restore

The PVC contains TWS settings, not account or market state. Use storage snapshots
or your platform backup tool before changing the image. Restore into an isolated
paper-trading release first, then confirm settings and login.

Because `jts.ini` is persistent, changing `gateway.timeZone` may not update an
existing installation. Back up the PVC and remove the retained setting only when
you intend upstream to regenerate it.

## Upgrade

Review both IB Gateway Docker and IBC release notes, verify the image manifest,
and test paper mode before live use. `Recreate` intentionally creates downtime
so old and new account sessions never overlap.

## Troubleshooting

```bash
kubectl -n ib-gateway get pods -o wide
kubectl -n ib-gateway describe pod -l app.kubernetes.io/instance=ib-gateway
kubectl -n ib-gateway logs deployment/ib-gateway --tail=200
kubectl -n ib-gateway get events --sort-by=.lastTimestamp
```

If readiness remains false, inspect login, two-factor, session-conflict, and
upstream connectivity messages. Avoid disabling probes merely to mark the Pod
ready; readiness is the closest available signal for an authenticated local API.

IBC was retired on 2026-09-01. Treat future compatibility changes as an explicit
operational risk and test every image update before production use.
