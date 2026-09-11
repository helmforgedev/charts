# Disposable runtime certificate

These certificate and private-key files belong only to the owned `pocket-id.example.test` validation fixture. They are
public test inputs, never deployment credentials. The fixture checks the certificate against its CA with Node TLS and
pins this exact leaf public key in Chromium; it does not disable certificate validation for arbitrary websites.
