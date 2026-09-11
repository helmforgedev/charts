# Text Embeddings Inference

Deploy Hugging Face [Text Embeddings Inference](https://github.com/huggingface/text-embeddings-inference)
as an authenticated HTTP embedding API with immutable model provenance and private native metrics.

## Features

- Official TEI 1.9.3 CPU image pinned by digest; optional pinned CUDA example.
- BGE-small English model pinned to an immutable revision, with 384-dimensional embeddings.
- Native `/embed` and OpenAI-compatible `/v1/embeddings` endpoints.
- Generated API Secret retained across Helm upgrades, existing Secrets and External Secrets Operator.
- Loopback-only inference process behind unprivileged NGINX; public metrics and Swagger paths blocked.
- Private native Prometheus endpoint, ServiceMonitor, PrometheusRule and explicit monitoring peers.
- Non-root containers, read-only filesystems, dropped capabilities, seccomp and no Kubernetes API token.
- Immutable Hub downloads or a complete read-only local model PVC with denied outbound traffic.
- Independent model replicas, CPU container HPA, disruption budgets and topology spreading.
- Ingress, Gateway API HTTPRoute, dual-stack Services and NetworkPolicy.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install embeddings helmforge/text-embeddings-inference \
  --namespace embeddings --create-namespace
```

Alternatively, use the OCI repository:

```bash
helm install embeddings oci://ghcr.io/helmforgedev/helm/text-embeddings-inference \
  --namespace embeddings --create-namespace
```

The pinned image requires Linux amd64. CPU requests and limits are starting points for the default small model;
benchmark realistic sequence lengths, concurrent clients and latency objectives before sizing production.
The chart does not deploy a database or vector index.

## Quick start

```bash
kubectl -n embeddings port-forward service/embeddings-text-embeddings-inference 8080:80
```

In another terminal, retrieve the generated credential into a shell variable without printing it:

```bash
TEI_API_KEY="$(kubectl -n embeddings get secret embeddings-text-embeddings-inference-auth \
  -o jsonpath='{.data.api-key}' | base64 --decode)"
curl --fail-with-body http://localhost:8080/embed \
  -H @- -H 'Content-Type: application/json' \
  -d '{"inputs":["A cat sits on the mat."],"normalize":true}' <<EOF
Authorization: Bearer ${TEI_API_KEY}
EOF
unset TEI_API_KEY
```

The bearer header is read from standard input; the key is not exported to the curl process environment.
Helm NOTES never print the credential. Native `/health` is intentionally unauthenticated.

## Model and vector contract

The default model is `BAAI/bge-small-en-v1.5`, revision `5c38ec7c405ec4b44b94cc5a9bb96e735b38267a`.
The CPU image loads its ONNX artifacts. `/info` identifies the model, revision, dtype, pooling and actual limits.
`model.servedName` changes the exposed model name; it does not download or select another model.

Pin `model.revision` to a full lowercase 40-character commit for Hub models. Changing the model, revision,
pooling, prompt, normalization or embedding dimension can invalidate an existing vector index. Create a separate
release and index, re-embed the corpus, compare retrieval quality and switch clients deliberately.
Rolling two incompatible models behind one Service can silently mix embedding spaces.

The default model produces embeddings, not reranking scores. A `/rerank` request against it returns 424.
Other upstream model families need compatible artifacts and their own acceptance tests; the supplied runtime
matrix validates the default embedding model. This chart deploys the HTTP image, not the separate gRPC variant.

## Authentication and secrets

Authentication is enabled by default. A generated Secret is reused through Helm `lookup` during upgrades.
For declarative renderers without live lookup, use `auth.existingSecret` to avoid random credentials on each render.
The Secret must contain `auth.secretKey` (default `api-key`). Disabling authentication is suitable only for a
deliberately restricted trust boundary. The native key is shared across API clients, without per-user authorization.

Private or gated Hub models can independently reference `model.hubToken.existingSecret`, key `token` by default.
Accept the upstream model terms and grant the token only the required repository access.
Neither token is embedded in the ConfigMap or command-line arguments.

The pinned native release logs parsed arguments at INFO, including API credentials. The chart fixes
`LOG_LEVEL=warn` and rejects overriding it with `extraEnv`; warning and error logs remain available.
Native process environment access is still privileged secret access. Rotation of an existing Secret requires
a Pod restart because environment variables are read at startup. Changing `auth.secretKey` is a credential change.

External Secrets uses the canonical `externalSecrets.items[]` contract. Point `auth.existingSecret` and/or
`model.hubToken.existingSecret` at the corresponding target Secrets. Install ESO and your SecretStore separately.
See [secret operations](docs/security.md).

## Storage and offline operation

Each Pod defaults to a 5Gi ephemeral download cache. Replacement may download the pinned model again.
`cache.persistence.enabled` creates or references a RWO PVC and requires one replica, Recreate and no HPA.
This cache is reproducible model data; the chart does not provide database backup jobs.

For offline operation, set `model.source: local` and `model.local.existingClaim` to a PVC containing the complete
model directory. It mounts read-only at `/models`; optional `subPath` selects a directory. Preserve provenance
and hashes outside the mutable volume. The correct weight format depends on the selected image backend.
Setting an offline environment flag alone does not guarantee that missing artifacts will not trigger downloads.

Local mode with default network isolation permits no outbound traffic. It must not need Hub DNS or HTTPS.
Multi-replica local models require storage access modes and node placement that permit every scheduled reader.
See [model lifecycle](docs/models.md) for seeding, rollback and index migration.

## Resource and admission limits

The default native limits are 64 concurrent requests, 2048 batch tokens, eight batch requests, 16 client batch
items and 1048576 payload bytes. The CPU backend forces exactly eight batch requests in this pinned image; other CPU values are rejected.
The proxy also enforces the payload byte limit. Token limits and payload bytes are different controls.
Requests beyond the client batch limit return 422; oversized bodies return 413. Inputs beyond the model's token
length fail unless truncation is enabled. Explicit client truncation can override the default behavior.

`inference.threads` controls Rayon, OpenMP and MKL thread budgets; tokenization workers are configured separately.
Increasing concurrency does not create more model memory. Large batches and sequence lengths can exhaust RAM
or VRAM. Admission limits are not per-client quotas or a durable queue. Apply edge rate limiting if needed.

## Availability and scaling

Recreate is the default strategy. It avoids concurrent old/new model instances but causes an update interruption.
For compatible models and independent ephemeral caches, use multiple replicas with RollingUpdate and sufficient
capacity for surge Pods. Every replica loads a complete model. Readiness checks execute native model health.

CPU HPA measures only container `tei`, not NGINX, and requires metrics-server and CPU requests. It is rejected
for GPU deployments. The production example uses two minimum replicas and a disruption budget allowing one
unavailable Pod. A PDB covers voluntary disruption, not a failed node or an application rollout.

The termination grace period must exceed the proxy read timeout (150 and 120 seconds by default). Native
shutdown is graceful, but Pod failure can lose in-memory requests. Clients need bounded retries and deadlines.
Do not claim zero downtime from readiness or grace periods alone.

## GPU deployment

[The CUDA example](examples/cuda.yaml) pins the official CUDA image and requests NVIDIA GPUs through the device
plugin. The native image entrypoint is preserved so upstream architecture selection and library setup execute.
Use compatible NVIDIA drivers, runtime and hardware, and benchmark the selected model on that hardware.
GPU manifest rendering and resource allocation are tested; GPU inference and throughput are not validated in
the CPU-only development cluster. No GPU performance claim is made.

## Networking

The Service exposes HTTP on port 80. NGINX listens on 8080; native TEI binds only to `127.0.0.1:8081`.
Do not expose the native process directly: upstream metrics share its HTTP listener and are unauthenticated.
Ingress and HTTPRoute terminate at the controlled public Service. Configure existing TLS infrastructure and
explicit ingress-controller peers. The chart does not create a Gateway or certificates.

NetworkPolicy allows same-namespace clients by default. Hub mode permits DNS and public HTTPS model downloads,
excluding private address ranges. CNI policies cannot filter by domain; use an egress proxy and explicit rules
when hostname restrictions are required. Local mode denies egress unless `extraEgress` explicitly permits it.
Policy enforcement requires a compatible CNI. Custom peer rules replace the default same-namespace rule.

`service.ipFamilyPolicy` and `service.ipFamilies` configure API and metrics Services. RequireDualStack needs a
dual-stack cluster; PreferDualStack may fall back. Both proxy listeners support IPv4 and IPv6.

## Observability

Enable `metrics.enabled`, explicit `metrics.ingressFrom` and optionally `metrics.serviceMonitor.enabled`.
The private listener on 9464 serves only native `/metrics`. It exposes TEI request counts, success counters and
inference duration histograms. Public `/metrics`, `/docs` and `/api-doc` paths return 404.
Configure Prometheus selectors to discover the ServiceMonitor and network peers to permit actual scraping.

The optional built-in PrometheusRule reports a down scrape target; it is not a semantic quality or latency SLO.
Add workload-specific recording and alert rules through `additionalRules`. Inspect native metrics for the pinned
release before writing queries. Metrics may disclose model/workload metadata and belong in the trusted network.

## Configuration reference

Every supported option and default is documented in [values.yaml](values.yaml), with validation in
[values.schema.json](values.schema.json). The [site guide](https://helmforge.dev/docs/charts/text-embeddings-inference)
includes the complete values reference. Unsafe storage, model revision, monitoring and scaling combinations fail
before Kubernetes resources are installed. `extraEnv` cannot override chart-owned model, auth or budget settings.

## Examples and operations

- [Simple CPU deployment](examples/simple.yaml)
- [Staging deployment](examples/staging.yaml)
- [Production CPU replicas](examples/production.yaml)
- [Private native monitoring](examples/metrics.yaml)
- [Local offline model](examples/offline.yaml)
- [External Secrets](examples/external-secrets.yaml)
- [CUDA GPU resources](examples/cuda.yaml)
- [Model lifecycle](docs/models.md), [security](docs/security.md), [operations](docs/operations.md)
- [Design decisions](DESIGN.md)

## Validation

Run `make validate-chart CHART=text-embeddings-inference` from helmforge-ops. The matrix covers native model
identity, finite normalized semantic vectors, OpenAI output equivalence, rejected requests, authentication,
credential retention, network isolation, real Prometheus, persistent cache, offline model inference, replicas,
CPU HPA and Pod replacement. GPU hardware and alternative model families require separate validation.

## Security Scan

### Security Scan: `text-embeddings-inference`

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **98.48485%** |

> Security posture acceptable.

Measured with Kubescape 4.0.13 against default manifests, without suppressed controls. This assesses
Kubernetes configuration; it does not certify upstream application or model security.

The unsuppressed C-0012 finding matches `MAX_BATCH_TOKENS=2048` and `TOKENIZATION_WORKERS=2`
by the word token. These are numeric inference settings, not credentials. API and Hub credentials use Secret references.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md). Report model compatibility and runtime evidence with deployment
details while keeping credentials and private input text out of issues and logs.
