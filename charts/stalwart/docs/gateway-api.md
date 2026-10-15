# Gateway API

The chart never creates a Gateway. Routes attach to operator-owned listeners
through `parentRefs`.

- HTTPRoute targets the HTTP Service and defaults to the HTTPS listener.
- TCPRoute targets the mail Service and is appropriate for SMTP, submission,
  IMAP, POP3, ManageSieve, and their STARTTLS upgrades.
- TLSRoute targets the mail Service and is appropriate only for implicit TLS
  passthrough such as SMTPS, IMAPS, and POP3S.

STARTTLS begins as plaintext and therefore cannot be SNI-routed by TLSRoute.
Controller support for raw TCP listeners and Experimental Gateway API CRDs
varies. Validate listener attachment and route status on the target controller.

Classic Ingress can coexist with HTTPRoute. It does not expose mail protocols.
Certificates may be terminated at a Gateway for HTTP or passed through to
Stalwart for implicit-TLS mail listeners.
