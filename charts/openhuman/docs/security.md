# Security

<!-- markdownlint-disable MD013 -->

The Pod runs as UID/GID 10001 with RuntimeDefault seccomp, no privilege escalation, no capabilities, no service-account token and a read-only root filesystem. Only the state claims and `/tmp` are writable.

Treat the RPC bearer as an administrative credential. It controls an agent that can execute tools and transmit data to configured providers. Keep access private, terminate TLS before any remote connection, configure exact allowed origins and apply narrow NetworkPolicy peers. Never commit bearer, provider or keyring values.
