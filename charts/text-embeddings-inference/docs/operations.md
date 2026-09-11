# Production operations

## Acceptance and capacity

Verify `/info`, real `/embed` output and `/v1/embeddings` compatibility before routing production traffic.
Use application-specific retrieval quality checks in addition to finite vector shape. Load-test realistic token
lengths and batch distributions; CPU, RAM and VRAM costs depend on the selected model and backend.
The default resources support the small validation model and do not constitute a capacity recommendation for all models.

Multiple replicas independently load model weights. CPU HPA requires metrics-server and measures container `tei`.
Increasing replicas can increase Hub traffic during a cold rollout. Persistent RWO cache disables this topology.
For local models, the existing volume must be readable by every scheduled replica.

## Monitoring

Enable the private metrics listener and select real Prometheus Pods with explicit namespace/Pod peers.
Install Prometheus Operator CRDs before enabling ServiceMonitor or PrometheusRule. Prometheus must select the
ServiceMonitor labels and namespace. A ServiceMonitor object alone does not prove a successful scrape.

Inspect `up` for the metrics endpoint and native `te_request_count`, `te_request_success` and inference-duration
histograms after real requests. The default alert detects a down or absent target; define latency/error SLOs from measured
traffic and the exact release's metric labels. Restrict access to monitoring metadata.

## Troubleshooting

| Symptom | Check and correction |
| --- | --- |
| Pod remains Pending | Inspect node architecture, CPU/RAM requests, PVC binding and device-plugin resources. |
| Model download fails | Check pinned revision, artifact availability, Hub token permissions and DNS/public HTTPS policy. |
| Gated model returns 401/403 during download | Accept model terms and supply a separate authorized Hub token Secret. |
| Native container cannot write cache | Check fsGroup 1000 support and existing-claim ownership; inspect storage driver behavior. |
| Offline startup tries to resolve missing artifacts | Verify the complete backend-specific model directory and local source selection. |
| API returns 401 | Check the referenced Secret key and client bearer credential; restart Pods after rotation. |
| API returns 413 | Reduce request bytes or deliberately increase both the chart payload budget and capacity. |
| API returns 422 | Inspect input token length and client batch count; truncation may discard meaningful input. |
| Reranking returns 424 | The default embedding model is not a reranker; select and validate an appropriate model separately. |
| OOMKilled or GPU allocation failure | Reduce concurrent/batch/token budgets or reserve sufficient model and activation memory. |
| Startup health returns 502 | NGINX may start before model loading finishes; inspect native logs and startup-probe budget. |
| Prometheus target absent | Check ServiceMonitor namespace/label selection and installed Operator CRDs. |
| Metrics target is down | Check explicit monitoring peers, Service endpoints and the private metrics port. |
| CPU HPA has unknown metrics | Check metrics-server health, CPU requests and container `tei` resource metrics. |
| Model outputs changed after upgrade | Compare revision, dtype, pooling, prompts and normalization against index provenance. |
| Rolling update stalls | Check surge capacity and volume access; do not use RollingUpdate with the RWO cache. |

## Recovery and rollback

Retain declared values, immutable model provenance and credential references. Download cache can be reconstructed;
local model volumes need a separate artifact copy or snapshot strategy. This chart contains no user-document or
vector-index backup job. Restore your external vector index together with its corresponding model contract.

After restoring or rolling back, verify credentials and actual vector output again. Keep client retry budgets
bounded: in-memory requests are not durable, and repeated load during recovery can delay model readiness.
