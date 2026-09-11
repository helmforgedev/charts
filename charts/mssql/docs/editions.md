# SQL Server versions and editions

The image tag selects the SQL Server engine release. `sql.edition` selects the edition and its feature limits. Changing one does not imply changing
the other.

## Select an edition

The default edition is `Express`. SQL Server resources are created only after explicit `license.acceptEULA: true`. Setting this value records your
acceptance of Microsoft's SQL Server license terms; the chart does not provide a commercial SQL Server license.

```yaml
license:
  acceptEULA: true
sql:
  edition: Express
```

| Value | Intended use and version compatibility |
| --- | --- |
| `Express` | Free edition for small applications, subject to edition capacity and feature limits. Supported on both engine tracks. |
| `Developer` | Development and testing. Maps to `EnterpriseDeveloper` on SQL Server 2025 and `Developer` on SQL Server 2022. |
| `EnterpriseDeveloper` | Enterprise feature set for development and testing on SQL Server 2025. |
| `StandardDeveloper` | Standard feature set for development and testing on SQL Server 2025. |
| `Standard` | Production use requires an appropriate Standard license. |
| `EnterpriseCore` | Enterprise edition with core-based licensing; production use requires an appropriate license. |
| `Enterprise` | Legacy Enterprise Server + CAL licensing, limited to 20 cores; unavailable for new agreements. Prefer `EnterpriseCore` for a new core-licensed deployment. |
| `Web` | SQL Server 2022 only, subject to its licensing terms. |
| `Evaluation` | Enterprise features for a time-limited evaluation of 180 days. |
| `ProductKey` | Read a product key from the Secret named by `license.existingSecret`, using `license.productKeyKey`. |

Developer editions are not licensed for production. The chart's production deployment features do not change that restriction. Paid editions are not
claimed as runtime tested without corresponding licensing; see the release validation evidence for the editions actually exercised.

For a product key, create the Secret through your approved secret-management process and reference it:

```yaml
license:
  acceptEULA: true
  existingSecret: sql-server-license
  productKeyKey: product-key
sql:
  edition: ProductKey
```

Never place a product key in a plain values file, command argument, ConfigMap, or support log. The Secret value must have the product-key format
required by Microsoft.

## Express capacity and backup differences

| Limit or feature | SQL Server 2025 Express | SQL Server 2022 Express |
| --- | --- | --- |
| Maximum relational database size | 50 GB | 10 GB |
| Maximum buffer pool | 1,410 MB | 1,410 MB |
| Maximum compute | Lesser of 1 socket or 4 cores | Lesser of 1 socket or 4 cores |
| SQL Server Agent | Unavailable | Unavailable |
| Native backup compression | Unavailable | Unavailable |
| Native encrypted backups and TDE | Unavailable | Unavailable |
| Native S3 REST backup connector | Unavailable | Unavailable |

The buffer pool limit is not the total container memory requirement. SQL Server also needs memory for execution, connections, and other engine
components.

The chart's S3 automation uses native full `COPY_ONLY` backups to disk followed by an AWS CLI upload. This works without SQL Server Agent and does not
depend on the native S3 connector. Object-store encryption and access controls protect uploaded objects; they are separate from SQL Server's native
backup encryption features. Full copy-only backups do not provide point-in-time recovery.

`sql.agent.enabled` is optional for eligible editions and must remain disabled for Express. Enabling it does not configure SQL Agent jobs or turn this
chart into a high-availability deployment.

## Select an engine release

Use a pinned `image.tag` that includes its matching `@sha256:` digest. The default track is SQL Server 2025; the SQL Server 2022 example pins a
compatible 2022 image. Both official Linux images require amd64 nodes. Emulation on ARM is not a supported deployment contract.

SQL Server 2025 and SQL Server 2022 CU20 or later support cgroup v2 resource constraints. Retain that floor when selecting another 2022 tag. Changing
only the tag while retaining a previous digest continues to pull the image identified by the digest, so update both together.

Verify the live engine and edition after installation or an approved migration:

```sql
SELECT
  SERVERPROPERTY('ProductVersion') AS ProductVersion,
  SERVERPROPERTY('ProductMajorVersion') AS ProductMajorVersion,
  SERVERPROPERTY('Edition') AS Edition,
  SERVERPROPERTY('EngineEdition') AS EngineEdition;
```

An edition change can remove features used by existing databases. An engine upgrade can change database file compatibility. Neither is equivalent to
an ordinary configuration edit. Test the supported Microsoft migration path against a restored copy, check edition-dependent features, and retain a
recoverable backup before modifying production. An older image cannot be assumed to open files upgraded by a newer engine.

## Upstream references

- [SQL Server environment variables and edition identifiers](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-configure-environment-variables?view=sql-server-ver17)
- [SQL Server 2025 editions and features](https://learn.microsoft.com/en-us/sql/sql-server/editions-and-components-of-sql-server-2025?view=sql-server-ver17)
- [SQL Server 2022 editions and features](https://learn.microsoft.com/en-us/sql/sql-server/editions-and-components-of-sql-server-2022?view=sql-server-ver16)
- [Deploy SQL Server containers](https://learn.microsoft.com/en-us/sql/linux/containers/deploy?view=sql-server-ver17)
- [Kubernetes resource and cgroup guidance](https://learn.microsoft.com/en-us/sql/linux/containers/kubernetes-best-practices-statefulsets?view=sql-server-ver17)
