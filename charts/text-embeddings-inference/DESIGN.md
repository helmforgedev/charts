# Text Embeddings Inference design

## Architecture

Clients reach a ClusterIP Service and unprivileged NGINX. NGINX proxies inference to native TEI on loopback.
An optional separate metrics Service reaches a metrics-only NGINX listener. Both containers run as UID/GID 1000
with read-only root filesystems and writable temporary directories. The Pod has no Kubernetes API credential.

## Native behavior and security boundary

TEI 1.9.3 serves unauthenticated metrics on its HTTP API listener. A declared Prometheus port does not create
a private HTTP exporter in this image. The proxy is therefore a required boundary, not an optional exporter.
Public paths deny metrics and API documentation, and NetworkPolicy separately authorizes metrics clients.
The native process retains its official entrypoint, which is essential to CUDA architecture selection.

Native INFO startup logging serializes the API key. LOG_LEVEL is fixed at warn and reserved against override.
Credentials are environment references to Kubernetes Secrets; generated keys use lookup during live upgrades.
Declarative render-only installations should use externally managed Secrets.

## Reproducibility and persistence

Image digests and Hub commit revisions are independent pins. The default CPU ONNX model is small enough for
the automated cluster and produces meaningful semantic embeddings. Model cache is reproducible, not business data.
RWO cache is restricted to a single Recreate replica. Multiple replicas use independent caches or an explicitly
compatible existing local-model volume. Offline mode selects the local directory, not an environment hint.

## Availability tradeoffs

Recreate is intentionally the default because a model change can alter vector meaning without an HTTP failure.
RollingUpdate is opt-in for compatible contracts. Model/index migrations use distinct releases and indexes.
CPU HPA targets inference CPU only; no unvalidated GPU utilization scaler is included. PDB validation prevents
a singleton budget from obstructing voluntary maintenance. Neither PDB nor graceful termination provides durability.

## Scope and evidence

The chart serves HTTP embedding models. It has no database, vector store, durable work queue, model training,
tenant authorization or gRPC server. Native API tests verify actual vectors and identity rather than a TCP socket.
The CPU matrix verifies existing/ESO credentials, cache, local offline artifacts, metrics and scaling. CUDA
manifests preserve upstream setup and request devices, but hardware-specific inference is outside the local lab.
