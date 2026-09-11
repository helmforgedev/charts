# Private native enrollment

The initial behavioral gate passed native enrollment, ordinary-user authentication,
closed signup, real resume/PDF content, Pod replacement and network-boundary checks.
The complete production profile matrix is still undergoing acceptance.

Reactive Resume does not provide a first-user exception to disabled signup. The
chart therefore starts an unchanged native server inside an initialization
container, creates the initial ordinary user through native signup, verifies a
native login/session, stops that server, and only then permits the public proxy
and ordinary application containers to start. It does not promote that account
to administrator or write password hashes into PostgreSQL.

## Required network boundary

The native server binds to wildcard port 3010. Its image has no supported loopback
binding option. An enforcing Kubernetes NetworkPolicy implementation and trusted
namespace policy administration are requirements, not optional hardening.

Before enrollment, the same init process opens harmless listeners on 3010 and 3011. A separate helper verifies that 3011 is reachable while 3010 is blocked.
It targets only its actual TCP caller at those fixed ports. Requests and responses
use a separate HMAC key; application passwords, session cookies and database
credentials are never sent to the helper.

The probe runs for every init attempt and every Pod address family. Its internal
Service uses PreferDualStack independently of public Service exposure. The native
listener is checked locally before and after the remote sample, and every harmless
connection is closed before the native application starts. No phase relabeling or
temporary allow rule changes the Pod's isolation between those steps.

These are bounded observations. NetworkPolicies are additive: another allow rule,
an untrusted policy controller or a broken CNI can invalidate the boundary. The
helper cannot prove universal denial from every source. Its egress must allow both
probe ports so that blocked helper egress cannot manufacture a successful result.
Node traffic, privileged debug access and cluster administrators are outside the
ordinary Pod isolation boundary. Audit injected containers and policy ownership.

## Credentials and retained identity

Configure the initial name, email and username before installation. Supply an
existing Secret containing a password of 16 to 64 characters (at most 72 UTF-8
bytes and 64 JavaScript string units, matching native bcrypt/auth limits); alternatively Helm
generates one. The password and helper key are mounted only in initialization.
Ordinary application containers receive the retained AUTH_SECRET and independent
ENCRYPTION_SECRET, plus connection credentials.

The application PVC retains a fingerprint of both native keys and the initial
user ID. An existing user database must match that marker before native migrations
start. Initialization does not reset a password or rename an existing account.
Missing keys, marker or initial account require an explicit migration/recovery
review. A crash after native signup but before writing the marker also fails
closed; it does not retry signup and silently adopt an unrelated database.

## Operational boundaries

Ordinary operation keeps native signup disabled. A second proxy rule blocks the
public signup namespace. Initial-session verification over isolated loopback is
not evidence of browser HTTPS cookie behavior; that requires separate acceptance
through the real public origin.

Native SMTP delivery and password recovery passed behavioral acceptance. Additional-user
enrollment is outside the chart's initial account contract. Without SMTP, upstream can print sensitive email
links to its logs. Bootstrap output is suppressed for that reason. The public proxy
also blocks password-reset requests, verification-email requests and email changes
until authenticated SMTP support is configured and accepted.

If native startup fails, initialization retains a mode-0600 diagnostic file at
`/tmp/helmforge-native-bootstrap.log`. It may contain sensitive native output and
is restricted to the workload identity and authorized cluster administrators.
Initialization deletes it before ordinary containers start successfully. Public
bootstrap logs report only the chart-owned failure stage.
