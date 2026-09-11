# Ryot authentication and integration boundaries

Use the pinned release only with local accounts under this chart's production contract. Keep registration disabled and
retain a strong administrator override. Existing Secret values are checked before any application listener starts. The
bootstrap password is mounted only in the private initialization container.

## OIDC

Ryot v10.5.0's native login resolver accepts a stored OIDC subject without verifying a provider exchange. Disabling the
provider configuration alone does not protect an existing linked account. The chart therefore rejects SERVER_OIDC
overrides and refuses databases containing linked accounts before public startup. An isolated regression used only a new
disposable ordinary account, confirmed its session identity, then deleted the account through the native API.

Do not create OIDC-linked accounts through administrative APIs or import such accounts into a running deployment.
Perform any identity remediation separately under controlled access; this chart does not rewrite account identities.
Enable OIDC only after an upstream correction and a new authorization regression, not by removing the admission check.

## S3

Native S3 presigning and object deletion use application credentials without user or object ownership checks in this
release. FILE_STORAGE overrides are rejected and native storage credentials remain empty. A private bucket alone does
not supply missing application authorization. The default gate checks that storage stays disabled and signing/delete
requests cannot perform useful operations.

## Provider APIs and SMTP

Supply unrelated provider credentials through `extraEnv` Secret key references and allow only their required network
destinations. Do not place tokens directly in values or expose the administrator override in a browser URL.

SMTP uses implicit TLS on port 465 with the pinned Rust library's compiled public trust roots. A mounted Node/private CA
bundle does not establish trust for that transport. The native notification test can return true even when delivery
fails; verify a received message before relying on notifications. No SMTP delivery fixture is asserted by this chart.

Source evidence:
[authentication service](https://github.com/IgnisDa/ryot/blob/v10.5.0/crates/services/user/src/authentication_operations.rs),
[storage resolver](https://github.com/IgnisDa/ryot/blob/v10.5.0/crates/resolvers/file-storage/src/lib.rs).
