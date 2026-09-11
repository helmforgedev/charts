# Retained state and recovery boundary

Fresh-database and fresh-volume restoration still require behavioral acceptance
before this chart is released.

## State that belongs together

Preserve the PostgreSQL database, local upload PVC and the Secret containing
`AUTH_SECRET` and `ENCRYPTION_SECRET` as one recovery set. PostgreSQL stores native
users, sessions, resume contents, ownership and authentication metadata. The PVC
stores uploaded files and `.helmforge-identity.json`. The marker contains the
initial native user ID and a fingerprint of the two retained keys; it is not a
substitute for backing up those Secret values.

`AUTH_SECRET` protects native authentication. `ENCRYPTION_SECRET` protects native
provider credentials when those features are used. Replacing a Secret with a new
random value is not an ordinary password rotation. The chart refuses an existing
user database when the matching marker or initial account is missing, or when the
retained key fingerprint differs.

The bootstrap password Secret is only used for initial enrollment. Its value is
not reapplied to an existing user account on restart or Helm upgrade. Native
account changes remain native; the initializer does not reset passwords or
promote an account into administrator privileges.

## Coordinated recovery

Quiesce the application before collecting a database dump and upload-volume
snapshot. Restore the database and files into fresh destinations with matching
role ownership, PVC permissions and retained native keys. Keep the application
closed until the complete recovery set is present. Preserve the hidden identity
marker when copying files; a shell wildcard that omits dotfiles is insufficient.

Recovering only PostgreSQL can leave missing files. Recovering only the PVC can
leave missing owners and metadata. Restoring a different database with an old
marker deliberately fails admission instead of silently claiming the instance.

Before reopening service, validate a retained native login, an existing private
resume, the original upload bytes and a generated PDF containing that resume's
content. The acceptance profile performed these checks against fresh database and
PVC resources, including the original authenticated session. Its archive includes
hidden top-level entries while preserving the storage provider's mount-root metadata.
