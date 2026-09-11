// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {createHash, randomUUID} from 'node:crypto';

const snapshots = new Map();
const identifier = value => {
  assert.match(value, /^[A-Za-z_][A-Za-z0-9_]{0,127}$/);
  return `[${value}]`;
};
const literal = value => `N'${value.replaceAll("'", "''")}'`;

/** Prove SQL Agent executes a real TSQL step, rather than merely accepting configuration. */
export async function validateAgent({sql, values}) {
  if (!values.sql?.agent?.enabled) return;
  const suffix = randomUUID().replaceAll('-', '');
  const job = `helmforge_agent_acceptance_${suffix}`;
  const tableName = `agent_acceptance_${suffix}`;
  const table = `acceptance.dbo.${identifier(tableName)}`;
  const jobLiteral = literal(job);
  // SQL readiness can precede Agent readiness. Retry only its explicit startup
  // error; authentication, permission, transport and other SQL failures stay fatal.
  const startingDeadline = Date.now() + 45000;
  const agentSql = async statement => {
    for (;;) {
      try {
        return sql(statement);
      } catch (error) {
        const output = [error?.message, error?.stdout, error?.stderr].filter(Boolean).map(String).join('\n');
        const numbers = [...output.matchAll(/\bMsg\s+(\d+)\b/g)].map(match => Number(match[1]));
        if (!numbers.length || numbers.some(number => number !== 14258) || Date.now() >= startingDeadline) throw error;
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
  };
  let failed = false;
  try {
    sql(`CREATE TABLE ${table}(id int PRIMARY KEY, marker nvarchar(80) NOT NULL);`);
    const command = `INSERT dbo.${identifier(tableName)} VALUES(1,N'agent executed TSQL');`;
    await agentSql(`USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name=${jobLiteral})
  EXEC dbo.sp_add_job @job_name=${jobLiteral}, @enabled=1, @owner_login_name=N'sa';`);
    await agentSql(`USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysjobsteps s JOIN dbo.sysjobs j ON j.job_id=s.job_id
  WHERE j.name=${jobLiteral} AND s.step_name=N'write acceptance marker')
EXEC dbo.sp_add_jobstep @job_name=${jobLiteral}, @step_name=N'write acceptance marker',
  @subsystem=N'TSQL', @database_name=N'acceptance', @command=${literal(command)},
  @on_success_action=1, @on_fail_action=2, @retry_attempts=0;`);
    await agentSql(`USE msdb;
IF NOT EXISTS (SELECT 1 FROM dbo.sysjobservers s JOIN dbo.sysjobs j ON j.job_id=s.job_id WHERE j.name=${jobLiteral})
  EXEC dbo.sp_add_jobserver @job_name=${jobLiteral}, @server_name=N'(local)';`);
    await agentSql(`EXEC msdb.dbo.sp_start_job @job_name=${jobLiteral};`);
    const deadline = Date.now() + 30000;
    let complete = false;
    while (Date.now() < deadline) {
      const status = sql(`SELECT COALESCE((SELECT TOP(1) h.run_status FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON j.job_id=h.job_id
WHERE j.name=${jobLiteral} AND h.step_id=0 ORDER BY h.instance_id DESC), -1);`);
      assert.ok(status !== '0' && status !== '3', 'SQL Agent acceptance job failed or was canceled');
      if (status === '1') {
        complete = true;
        break;
      }
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    assert.ok(complete, 'SQL Agent must finish the TSQL job within 30 seconds');
    assert.equal(sql(`SELECT COUNT(*) FROM ${table} WHERE id=1 AND marker=N'agent executed TSQL';`), '1', 'SQL Agent writes the expected acceptance marker exactly once');
  } catch (error) {
    failed = true;
    throw error;
  } finally {
    try {
      // UUID names scope cleanup to resources created by this invocation; no schedules are created.
      await agentSql(`USE msdb;
IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name=${jobLiteral})
  EXEC dbo.sp_delete_job @job_name=${jobLiteral}, @delete_history=1, @delete_unused_schedule=0;
DROP TABLE IF EXISTS ${table};`);
    } catch {
      if (failed) console.error('SQL Agent acceptance cleanup also failed; inspect only the invocation-owned job and table');
      else throw new Error('SQL Agent acceptance cleanup failed');
    }
  }
  console.log('PASS SQL Server Agent executed a real TSQL job and its temporary job/table were removed');
}

/** Call before and after Pod replacement; credentials never leave the mounted files. */
export function validateInitialization({k, json, sql, values, pod, phase}) {
  const scripts = values.initdb?.scriptsConfigMaps ?? [];
  const snapshotKey = `${values.fullnameOverride || pod}:initialization`;
  const previous = snapshots.get(snapshotKey);
  const current = {};
  let expectedScripts = 0;
  for (const name of scripts) {
    const configMap = json(['get', 'configmap', name, '-o', 'json']);
    for (const [filename, content] of Object.entries(configMap.data ?? {})) {
      if (!filename.endsWith('.sql')) continue;
      expectedScripts++;
      const scriptName = `${name}/${filename}`;
      const predicate = `script_name=${literal(scriptName)}`;
      const expectedHash = createHash('sha256').update(content).digest('hex');
      assert.equal(sql(`SELECT COUNT(*) FROM master.dbo.helmforge_bootstrap WHERE ${predicate}`), '1', 'Initialization script has exactly one durable ledger row');
      assert.equal(sql(`SELECT sha256 FROM master.dbo.helmforge_bootstrap WHERE ${predicate}`), expectedHash, 'Ledger matches the mounted script content');
      current[scriptName] = sql(`SELECT CONVERT(varchar(33),applied_at,126) FROM master.dbo.helmforge_bootstrap WHERE ${predicate}`);
      assert.ok(current[scriptName], 'Ledger records application time');
    }
  }
  assert.equal(sql('SELECT COUNT(*) FROM master.dbo.helmforge_bootstrap'), String(expectedScripts), 'Only declared initialization scripts are applied');
  if (previous) assert.deepEqual(current, previous, 'Pod replacement must not reapply initialization scripts');
  else snapshots.set(snapshotKey, current);

  const index = (values.initdb?.databases ?? []).findIndex(db => db.name === 'application' && db.username === 'application');
  if (index >= 0 && scripts.includes('mssql-app-scripts')) {
    const db = values.initdb.databases[index];
    const database = identifier(db.name);
    identifier(db.username);
    const appSql = statement => {
      try {
        return k(['exec', '-i', pod, '-c', 'mssql', '--', '/bin/bash', '-ec',
          `export SQLCMDPASSWORD="$(cat /applications/${index}/password)"; exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U ${db.username} -d ${db.name} -C -b -V 11 -x -l 5 -t 10 -h -1 -W`],
        `SET NOCOUNT ON;\n${statement}\nGO\n`).trim();
      } catch {
        // Do not attach exec errors: their captured output can contain sensitive server data.
        throw new Error('Application initialization SQL failed; inspect credentials and grants privately');
      }
    };
    assert.equal(appSql("SELECT IS_SRVROLEMEMBER('sysadmin')"), '0', 'Application login must not be sysadmin');
    assert.equal(appSql("SELECT HAS_PERMS_BY_NAME(NULL,NULL,'CREATE ANY DATABASE')"), '0', 'Application login cannot create arbitrary databases');
    assert.equal(appSql("SELECT COUNT(*) FROM dbo.installation_marker WHERE id=1 AND marker=N'initialized once'"), '1', 'Initialization marker remains intact');
    assert.throws(() => appSql('SELECT COUNT(*) FROM master.dbo.helmforge_bootstrap'), /Application initialization SQL failed/, 'Application login cannot read the administrative ledger');
    if (!previous) {
      appSql("CREATE TABLE dbo.application_runtime_probe(id int PRIMARY KEY, value nvarchar(80)); INSERT dbo.application_runtime_probe VALUES(1,N'application data survives restart');");
    }
    assert.equal(appSql('SELECT value FROM dbo.application_runtime_probe WHERE id=1'), 'application data survives restart', 'Limited application login can read its persisted application data');
    assert.equal(sql(`SELECT recovery_model_desc FROM sys.databases WHERE name=${literal(db.name)}`), db.recoveryModel ?? 'SIMPLE', 'Initial recovery model matches the declared contract');
    console.log(`PASS ${phase}: limited application credentials, durable marker and initialization ledger`);
  } else if (scripts.length) {
    console.log(`PASS ${phase}: immutable initialization script ledger`);
  }
}
