# Papra persistent extraction queue

The chart selects the native libSQL task driver with `file:/app/app-data/db/tasks.sqlite` and a one-second poll
interval. This database is separate from the application database, including when the application uses remote libSQL.
The singleton's data volume therefore remains part of the deployment's durable state in every database mode.

`tasks.workerEnabled=true` runs the native web API and worker together. Setting it false selects native web-only mode;
uploads remain available but extraction and scheduled maintenance pause. Reenable it after maintenance. The verified
queue profile uploads in web-only mode, reads the pending task without modifying SQL, replaces the pod, verifies the
same pending task ID, then resumes the worker and checks that task completes and its document becomes searchable.

## Recovery boundaries

The pinned Cadence driver marks a claimed task `processing` and only consumes `pending` tasks. It has no processing
lease, heartbeat or stale-job reaper. A process killed during extraction can leave a processing task stuck. Native
extraction sets no retries; failures remain failed. No stable Papra HTTP/CLI requeue operation was found for this
release. Do not reset all processing rows automatically or infer that a restart retries interrupted work.

Document insertion and enqueue are separate operations, so a crash between them can leave an original without its
extraction task. Keep original files recoverable and inspect task status, document content and native worker logs when
search results lag. A successful upload or a healthy HTTP endpoint does not prove extraction completed.

Completed tasks remain in this release's queue. Monitor queue database growth and establish an operator-reviewed
retention procedure appropriate to the installed upstream version. The chart does not delete task history behind the
application's back.

## Confidentiality and backup

The task driver exposes no encryption-key setting. Application database encryption does not encrypt tasks.sqlite.
Extraction payloads contain document/organization identifiers and OCR languages rather than original bytes or extracted
text, but generic task results and error details may still be private. Protect the PVC and backup destination; use
storage-level encryption when all local metadata must be encrypted at rest.

Stop the writer and include all of `db/`, its WAL/SHM files and `documents/` in a consistent local recovery archive.
Restore application data, queue state and key material together. A restored pending task can run; a restored processing
task retains the native limitation described above.
