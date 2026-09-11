# Native SMTP and password recovery

Enable SMTP with a certificate-matching host, sender address, authentication username and existing password Secret.
`smtp.from` is the sender address, without a display-name wrapper. The native display name is Twenty. Native port 465 is
required for implicit TLS; a Kubernetes Service can map it to an unprivileged backend listener. The chart does not
expose opportunistic or disabled TLS modes.

The initializer verifies TLS and authentication before starting the native enrollment flow. A private CA Secret can
extend trust without disabling certificate or hostname checks. Additional CA trust is shared by native Node
integrations.

Upstream defaults to a LOGGER mail driver that includes recovery links in logs. When SMTP is disabled, this chart
instead selects the SMTP driver against a refused loopback listener. No delivery is available in that mode. The upstream
GraphQL mutation can acknowledge a request before asynchronous delivery fails; an HTTP 200 or `success: true` is not
proof that a message was delivered.

Enable actual SMTP before depending on password recovery or invitations. The acceptance profile checks the received
sender, recipient and authenticated SMTP identity, follows the delivered native reset token, verifies single-use
behavior, rejects the old password and authenticates with the recovered password. The new native password must survive
Pod replacement while the initial Secret stays unchanged. This acceptance passed,
including authenticated delivery, wrong credentials, untrusted CA and a resolvable
hostname absent from the certificate. The original post-reset session, company,
attachment and retained identity also survived replacement.

The chart never changes the native GraphQL bundle or attempts to authorize GraphQL mutations using a proxy regular
expression. Configuration and native account permissions remain distinct controls.
