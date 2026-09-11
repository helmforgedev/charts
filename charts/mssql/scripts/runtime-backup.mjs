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
  let preserveDirectory;
  let failedUploadDirectory;
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
    restoreSpec.volumes.push({name: 'failure-work', emptyDir: {sizeLimit: '16Mi'}});
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
    server.volumeMounts.push({name: 'failure-work', mountPath: '/work'});
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

    // Faults happen through exec in healthy fixture Pods, not crashing SQL/workload containers.
    preserveDirectory = '/backup/hf-failure-preserve';
    vexec(['mkdir', '--', preserveDirectory]);
    k(['exec', '-i', verifier, '-c', 'upload', '--', '/bin/bash', '-ec',
      'cat > /backup/hf-failure-preserve/operator-note'], 'preserve unrelated diagnostic\n');
    const nativeFailure = databaseList => k(['exec', restorePod, '-c', 'mssql', '--', '/bin/bash', '-ec',
      'export SQLCMDPASSWORD="$(cat /auth/backup-password)"; exec env SQL_HOST=localhost SQL_PORT=1433 SQLCMDUSER=hf_backup SSL_CERT_FILE=/tls/ca.crt BACKUP_COMPRESSION=false "$@"',
      'backup-failure-validation', `BACKUP_DATABASES=${databaseList}`, '/bin/bash', '/config/backup.sh'], undefined, 45000);
    assert.throws(() => nativeFailure('acceptance hf_intentionally_missing_database'),
      'failure after one completed native archive must report an error');
    const nativeDiagnostic = JSON.parse(vexec(['cat', '/backup/.last-failure']));
    assert.equal(nativeDiagnostic.phase, 'native');
    assert(nativeDiagnostic.exitCode > 0);
    assert.match(nativeDiagnostic.runId, /^mssql-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{16}$/);
    assert.equal(freshSql(`SELECT COUNT(*) FROM msdb.dbo.backupmediafamily WHERE physical_device_name=N'/backup/${nativeDiagnostic.runId}/acceptance.bak'`), '1',
      'first database backup must actually have completed before the second fails');
    vexec(['test', '!', '-e', `/backup/${nativeDiagnostic.runId}`]);
    assert.equal(vexec(['cat', `${preserveDirectory}/operator-note`]).trim(), 'preserve unrelated diagnostic');

    freshSql('CREATE DATABASE [hf_failure_aux];');
    freshSql('USE [hf_failure_aux]; CREATE USER [hf_backup] FOR LOGIN [hf_backup]; ALTER ROLE [db_backupoperator] ADD MEMBER [hf_backup];');
    nativeFailure('acceptance hf_failure_aux');
    // Transfer only small native metadata; the real archives stay on the shared PVC.
    for (const file of ['run-id', 'files.tsv', 'manifest.json']) {
      const content = k(['exec', restorePod, '-c', 'mssql', '--', 'cat', `/work/${file}`]);
      k(['exec', '-i', verifier, '-c', 'upload', '--', '/bin/bash', '-ec', `cat > /work/${file}`], content);
    }
    const failedRun = vexec(['cat', '/work/run-id']).trim();
    assert.match(failedRun, /^mssql-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{16}$/);
    failedUploadDirectory = `/backup/${failedRun}`;
    k(['exec', '-i', verifier, '-c', 'upload', '--', '/bin/bash', '-ec',
      `cat > ${failedUploadDirectory}/operator-note`], 'preserve file not owned by backup\n');
    const realAws = vexec(['/bin/bash', '-ec', 'command -v aws']).trim();
    assert.match(realAws, /^\/[A-Za-z0-9/_.-]+$/);
    const wrapper = `#!/bin/bash\nset -eu\nfor argument in "$@"; do\n  case "$argument" in */hf_failure_aux.bak) export AWS_SECRET_ACCESS_KEY=deliberately-invalid-ci-key ;; esac\ndone\nexec ${realAws} "$@"\n`;
    k(['exec', '-i', verifier, '-c', 'upload', '--', '/bin/bash', '-ec',
      'mkdir /work/fault-bin; cat > /work/fault-bin/aws; chmod 700 /work/fault-bin/aws'], wrapper);
    assert.throws(() => vexec(['/bin/bash', '-ec',
      'export PATH="/work/fault-bin:$PATH" AWS_MAX_ATTEMPTS=1; exec /bin/bash /config/upload.sh']),
    'the second real S3 request must fail with invalid signing credentials');
    const uploadDiagnostic = JSON.parse(vexec(['cat', '/backup/.last-failure']));
    assert.equal(uploadDiagnostic.runId, failedRun);
    assert.equal(uploadDiagnostic.phase, 'upload');
    assert(uploadDiagnostic.exitCode > 0);
    vexec(['test', '!', '-e', `${failedUploadDirectory}/acceptance.bak`]);
    vexec(['test', '!', '-e', `${failedUploadDirectory}/hf_failure_aux.bak`]);
    assert.equal(vexec(['cat', `${failedUploadDirectory}/operator-note`]).trim(), 'preserve file not owned by backup');
    assert.equal(vexec(['cat', `${preserveDirectory}/operator-note`]).trim(), 'preserve unrelated diagnostic');
    const partial = JSON.parse(aws(['s3api', 'list-objects-v2', '--bucket', values.backup.s3.bucket,
      '--prefix', `${values.backup.s3.prefix}/${failedRun}/`, '--output', 'json']));
    assert.deepEqual((partial.Contents ?? []).map(object => object.Key),
      [`${values.backup.s3.prefix}/${failedRun}/acceptance.bak`],
      'partial remote archive is preserved, but no completion manifest exists');
    aws(['s3api', 'head-object', '--bucket', values.backup.s3.bucket, '--key', manifestKey]);
    console.log('PASS failed second database and second S3 upload reclaim owned staging files, retain latest diagnostic and preserve unrelated files/completed remote backup');
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
        if (preserveDirectory) {
          vexec(['rm', '-f', '--', `${preserveDirectory}/operator-note`]);
          vexec(['rmdir', '--', preserveDirectory]);
        }
        if (failedUploadDirectory) {
          vexec(['rm', '-f', '--', `${failedUploadDirectory}/operator-note`]);
          vexec(['rmdir', '--', failedUploadDirectory]);
        }
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
