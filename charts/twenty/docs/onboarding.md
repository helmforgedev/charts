# Private administrator and workspace enrollment

The initial behavioral gate verified private enrollment, closed signup and retained identity. The complete production
integration gate is tracked in the chart README.

Twenty binds its native listener to unspecified addresses. A readiness probe or missing Service endpoints cannot isolate
it during first-administrator creation. The chart requires an enforcing CNI and trusted namespace policy ownership. Its
separate HMAC helper probes the caller's fixed native and control ports for every Pod address family before any private
native listener starts. These bounded observations do not prove universal denial against additive policies, untrusted
controllers, injected containers or node/cluster administrators.

After database admission, the initializer runs the native initialization and upgrade commands serially. It checks
process exit status, private command output and the SQL prerequisites that native setup can fail to create while
returning success. Cache flushes require their native completion marker. Native cache namespaces are separate from
retained BullMQ queue data.

An empty instance receives the configured administrator through native `signUp`. The native workspace flow creates and
activates the workspace, grants the initial administrator privileges and disables public invite links through
`updateWorkspace`. Public invites default to enabled upstream, so workspace creation alone is not a sufficient
private-installation check. No SQL password or privilege writes are used.

Native activation in 2.39.0 also creates demonstration companies, people, workflows,
opportunities and dashboards. The upstream activation API does not offer a switch
to skip this prefill. Review and remove unwanted examples through Twenty before
importing production records or enabling external integrations. Startup never
deletes workspace records automatically.

The initializer writes a pending ownership marker before enrollment to permit recovery from a process failure between
account and workspace creation. That pending flow can use the initial credentials to finish native enrollment. Once
ownership is complete, future startup follows the retained native user ID, workspace membership and encryption
fingerprint. It does not replay the original password or revert native email/password changes.

Existing users without the matching marker are not silently adopted. Missing administrator privileges or membership,
changed encryption identity, incomplete workspace activation or re-enabled public invite links block chart-managed
startup. Migrate ownership deliberately before adopting an existing installation.

The native administrator configuration is environment-owned through `IS_CONFIG_VARIABLES_IN_DB_ENABLED=false`. The
configuration UI becomes read-only; export effective database configuration before migrating to this contract. Native
workspace permissions remain database state and are checked separately.

Private command output uses a mode-0600 diagnostic file and is deleted before successful public startup. Authorized
operators can inspect it after a failed initialization. It can contain sensitive application diagnostics and must not be
copied into public issue reports without redaction.
