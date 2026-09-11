# Model lifecycle

## Immutable Hub models

Select a model supported by the pinned TEI backend, review its license and pin a full commit revision.
The default CPU backend needs the ONNX directory as well as tokenizer/configuration files. A repository that
works in another serving engine is not automatically compatible. Inspect `/info` after installation and submit
representative input to `/embed` before directing index-writing clients to the new endpoint.

Hub downloads require DNS and HTTPS, including artifact delivery hosts. The default policy allows public HTTPS
because CNI NetworkPolicy cannot express domain names. For gated models, create a separate minimal-scope Hub
token Secret and reference it through `model.hubToken`. Never use the inference API key as a Hub credential.

## Offline local model

Prepare a PVC with the complete model directory using a controlled artifact pipeline. Record repository, commit,
artifact hashes, license and image backend. For the default CPU model the directory includes `onnx/model.onnx`,
`config.json`, `tokenizer.json`, tokenizer/sentence configuration and pooling metadata. Verify the complete
bundle against the selected revision, rather than copying an arbitrary warm cache directory.

Set `model.source: local`, `model.local.existingClaim` and optionally `model.local.subPath`. Files are mounted
read-only at `/models`. The application cache and temporary directories remain writable for native startup.
With network isolation enabled and no `extraEgress`, the deployed Pod cannot download missing files. Test startup
and actual inference under that restriction. The CI fixture seeds the pinned public model before applying the
application policy; the workload then serves requests and restarts with outbound traffic denied.

## Cache ownership and capacity

The Pod uses fsGroup 1000. The storage driver must support appropriate volume ownership and permissions.
No root init container is required by the default chart. Reserve capacity for all artifacts and replacement
downloads. A small model cache does not bound in-memory model or batch allocations.

Persistent cache uses RWO storage, one replica and Recreate. Claim deletion depends on ownership: a chart-created
PVC is a release resource and may be deleted on uninstall. Use an existing claim or an explicit retention policy
when retaining downloaded artifacts is operationally necessary. Cache retention is not vector-index backup.

## Vector-index migration

1. Record the old model revision, prompts, pooling, dimensions and normalization used by indexing and queries.
2. Deploy the new contract under a separate release and endpoint.
3. Validate dimensions, stable outputs, retrieval quality and realistic resource use.
4. Re-embed source documents into a separate vector index with provenance metadata.
5. Switch indexing and query clients together; retain the old release/index for rollback.

Helm rollback can restore a Deployment but cannot translate vectors already written with a different model.
Rollback must restore the corresponding index and client settings. Do not mix incompatible models behind a
rolling Service and rely on HTTP health to detect semantic corruption.
