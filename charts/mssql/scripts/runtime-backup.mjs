// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';

/** Verify completed remote objects and restore into an independent, empty SQL instance. */
export async function validateBackup({k, json, apply, sql, values, name, pod, ns, context}) {
  assert.equal(context, 'k3d-helmforge-tests-wsl');
  assert.equal(ns, 'hf-validate-mssql');
  assert(values.backup.enabled);
  const started = Date.now();
  const verifier = `${name}-s3-verify`;
  const restorePod = `${name}-restore-verify`;
  const original = json(['get', 'pod', pod, '-o', 'json']);
  const backupVolume = original.spec.volumes.find(volume => volume.name === 'backup');
  assert(backupVolume?.persistentVolumeClaim, 'backup acceptance requires server-visible staging');
  const cronjob = json(['get', 'cronjob', `${name}-backup`, '-o', 'json']);
  const verifierSpec = structuredClone(cronjob.spec.jobTemplate.spec.template.spec);
  verifierSpec.initContainers = [];
  verifierSpec.nodeName = original.spec.nodeName;
  delete verifierSpec.affinity;
  verifierSpec.restartPolicy = 'Never';
  verifierSpec.terminationGracePeriodSeconds = 1;
  const uploader = verifierSpec.containers.find(container => container.name === 'upload');
  assert(uploader, 'the rendered CronJob must contain its official uploader');
  uploader.command = ['/bin/bash', '-ec', 'sleep 600'];
  delete uploader.args;
  verifierSpec.containers = [uploader];
  const fixtureMetadata = podName => ({
    name: podName,
    labels: {'helmforge.dev/runtime-fixture': 'true', 'app.kubernetes.io/component': 'restore-validation'},
  });
  const vexec = args => k(['exec', verifier, '-c', 'upload', '--', ...args]);
  const aws = args => vexec(['aws', '--region', values.backup.s3.region,
    ...(values.backup.s3.endpoint ? ['--endpoint-url', values.backup.s3.endpoint] : []), ...args]);
  let verifierCreated = false;
  let restoreCreated = false;
  let primaryFailure;
  let downloadDirectory;
  const downloaded = [];
  try {
    apply({apiVersion: 'v1', kind: 'Pod', metadata: fixtureMetadata(verifier), spec: verifierSpec});
    verifierCreated = true;
    k(['wait', '--for=condition=Ready', `pod/${verifier}`, '--timeout=45s'], undefined, 50000);
    const listing = JSON.parse(aws(['s3api', 'list-objects-v2', '--bucket', values.backup.s3.bucket,
      '--prefix', `${values.backup.s3.prefix}/`, '--output', 'json']));
    const completed = (listing.Contents ?? []).filter(object => object.Key.endsWith('/manifest.json'))
      .sort((left, right) => right.LastModified.localeCompare(left.LastModified));
    assert(completed.length > 0, 'S3 must contain a completed backup manifest');
    const manifestKey = completed[0].Key;
    aws(['s3api', 'get-object', '--bucket', values.backup.s3.bucket, '--key', manifestKey, '/work/remote-manifest.json']);
    const manifest = JSON.parse(vexec(['cat', '/work/remote-manifest.json']));
    assert.equal(manifest.schemaVersion, 1);
    assert.match(manifest.runId, /^mssql-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{16}$/);
    assert.equal(manifestKey, `${values.backup.s3.prefix}/${manifest.runId}/manifest.json`);
    assert.equal(manifest.backupType, 'full-copy-only');
    assert.equal(manifest.checksum, true);
    assert.equal(manifest.compression, values.backup.compression);
    assert(Array.isArray(manifest.files) && manifest.files.length > 0);
    assert.deepEqual(manifest.files.map(file => file.database).sort(), [...values.backup.databases].sort());
    downloadDirectory = `/backup/restore-${manifest.runId}`;
    vexec(['mkdir', '--', downloadDirectory]);
    const names = new Set();
    for (const file of manifest.files) {
      assert.match(file.database, /^[A-Za-z_][A-Za-z0-9_]{0,127}$/);
      assert.equal(file.file, `${file.database}.bak`);
      assert(!names.has(file.file), 'manifest archive names must be unique');
      names.add(file.file);
      assert(Number.isSafeInteger(file.sizeBytes) && file.sizeBytes > 0);
      assert.match(file.sha256, /^[0-9a-f]{64}$/);
      const destination = `${downloadDirectory}/${file.file}`;
      // Track even a partially written download for exact-path cleanup.
      downloaded.push(destination);
      aws(['s3api', 'get-object', '--bucket', values.backup.s3.bucket,
        '--key', `${values.backup.s3.prefix}/${manifest.runId}/${file.file}`, destination]);
      assert.equal(Number(vexec(['stat', '-c', '%s', '--', destination]).trim()), file.sizeBytes);
      assert.equal(vexec(['sha256sum', '--', destination]).trim().split(/\s+/)[0], file.sha256);
    }
    console.log(`PASS S3 completion manifest and independently downloaded SHA-256 (${manifest.files.length} archive(s))`);

    // The original database PVC is deliberately absent: master and user data start empty.
    const restoreSpec = structuredClone(original.spec);
    restoreSpec.volumes = restoreSpec.volumes.map(volume => volume.name === 'data'
      ? {name: 'data', emptyDir: {sizeLimit: '8Gi'}} : volume);
    assert(!restoreSpec.volumes.some(volume => volume.name === 'data' && volume.persistentVolumeClaim));
    restoreSpec.nodeName = original.spec.nodeName;
    delete restoreSpec.affinity;
    delete restoreSpec.hostname;
    delete restoreSpec.subdomain;
    delete restoreSpec.readinessGates;
    restoreSpec.restartPolicy = 'Never';
    restoreSpec.terminationGracePeriodSeconds = 5;
    restoreSpec.containers = restoreSpec.containers.filter(container => container.name === 'mssql');
    assert.equal(restoreSpec.containers.length, 1);
    const server = restoreSpec.containers[0];
    server.resources = {requests: {cpu: '1', memory: '4Gi'}, limits: {cpu: '2', memory: '4Gi'}};
    for (const variable of server.env) {
      if (variable.name === 'MSSQL_MEMORY_LIMIT_MB') variable.value = '3072';
    }
    apply({apiVersion: 'v1', kind: 'Pod', metadata: fixtureMetadata(restorePod), spec: restoreSpec});
    restoreCreated = true;
    k(['wait', '--for=condition=Ready', `pod/${restorePod}`, '--timeout=90s'], undefined, 95000);
    const freshSql = query => k(['exec', '-i', restorePod, '-c', 'mssql', '--', '/bin/bash', '-ec',
      'export SQLCMDPASSWORD="$(cat /auth/sa-password)"; export SSL_CERT_FILE=/tls/ca.crt; exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -N -b -V 11 -x -h -1 -W -s "|"'],
    `SET NOCOUNT ON;\n${query}\nGO\n`).trim();
    assert.equal(freshSql("SELECT COUNT(*) FROM acceptance.sys.tables WHERE name=N'verification'"), '0',
      'fresh instance must not already contain source data');
    assert.equal(freshSql("SELECT COUNT(*) FROM sys.databases WHERE name=N'restored_acceptance'"), '0');
    const acceptance = manifest.files.find(file => file.database === 'acceptance');
    assert(acceptance, 'backup fixture must include the seeded acceptance database');
    const archive = `${downloadDirectory}/${acceptance.file}`;
    const fileList = freshSql(`RESTORE FILELISTONLY FROM DISK=N'${archive}';`).split(/\r?\n/)
      .map(line => line.split('|').map(field => field.trim())).filter(fields => fields.length > 3);
    const dataFiles = fileList.filter(fields => fields[2] === 'D');
    const logFiles = fileList.filter(fields => fields[2] === 'L');
    assert.equal(dataFiles.length, 1, 'fixture uses one native data file');
    assert.equal(logFiles.length, 1, 'fixture uses one native log file');
    for (const logicalName of [dataFiles[0][0], logFiles[0][0]]) assert.match(logicalName, /^[A-Za-z_][A-Za-z0-9_]{0,127}$/);
    k(['exec', restorePod, '-c', 'mssql', '--', '/bin/bash', '-ec',
      'export SQLCMDPASSWORD="$(cat /auth/sa-password)"; exec env SQL_HOST=localhost SQL_PORT=1433 SQLCMDUSER=sa SSL_CERT_FILE=/tls/ca.crt RESTORE_DATABASE=restored_acceptance "$@"',
      'restore-validation', `RESTORE_FILE=${archive}`, `RESTORE_DATA_LOGICAL_NAME=${dataFiles[0][0]}`,
      `RESTORE_LOG_LOGICAL_NAME=${logFiles[0][0]}`, '/bin/bash', '/config/restore.sh'], undefined, 90000);
    assert.equal(freshSql('SELECT value FROM restored_acceptance.dbo.verification WHERE id=1'), 'persistent SQL data');
    assert.equal(freshSql('SELECT COUNT(*) FROM restored_acceptance.dbo.verification'), '1');
    assert.equal(freshSql("SELECT DATABASEPROPERTYEX(N'restored_acceptance',N'Status')"), 'ONLINE');
    // Permission tests are non-destructive even if the role contract regresses.
    assert.equal(sql("SELECT HAS_PERMS_BY_NAME(N'acceptance',N'DATABASE',N'SELECT')", 'hf_backup', 'backup-password'), '0');
    assert.equal(sql("SELECT HAS_PERMS_BY_NAME(NULL,NULL,N'CREATE ANY DATABASE')", 'hf_backup', 'backup-password'), '0');
    console.log('PASS restore into separate empty SQL storage, VERIFYONLY, DBCC CHECKDB and original application rows; backup account remains restricted');
  } catch (error) {
    primaryFailure = error;
    throw error;
  } finally {
    const cleanupErrors = [];
    if (restoreCreated) {
      try { k(['delete', 'pod', restorePod, '--wait=true', '--timeout=20s'], undefined, 25000); }
      catch (error) { cleanupErrors.push(error); }
    }
    if (verifierCreated) {
      try {
        for (const file of downloaded) vexec(['rm', '-f', '--', file]);
        if (downloadDirectory) vexec(['rmdir', '--', downloadDirectory]);
      } catch (error) { cleanupErrors.push(error); }
      try { k(['delete', 'pod', verifier, '--wait=true', '--timeout=15s'], undefined, 20000); }
      catch (error) { cleanupErrors.push(error); }
    }
    if (cleanupErrors.length) {
      if (primaryFailure) console.error('Backup validation cleanup also failed; original validation error retained');
      else throw new AggregateError(cleanupErrors, 'Backup validation fixture cleanup failed');
    }
  }
  console.log(`PASS backup recovery acceptance completed in ${Math.round((Date.now() - started) / 1000)}s`);
}
