# SPDX-License-Identifier: Apache-2.0
"""Run the official entrypoint and provision explicitly declared SQL resources."""
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

SQLCMD = '/opt/mssql-tools18/bin/sqlcmd'
READY = Path('/run/mssql/ready')
IDENTIFIER = re.compile(r'[A-Za-z_][A-Za-z0-9_]{0,127}\Z')


def ident(value):
    if not IDENTIFIER.fullmatch(value):
        raise ValueError('Unsupported SQL identifier')
    return '[' + value + ']'


def literal(value):
    return "N'" + value.replace("'", "''") + "'"


def password(key):
    value = Path('/auth', key).read_text().rstrip('\r\n')
    if not 8 <= len(value) <= 128 or '\x00' in value:
        raise ValueError('Credential length/format is invalid')
    return value


def sql(statement, user='sa', secret=None, timeout=60):
    env = dict(os.environ, SQLCMDPASSWORD=secret or password('sa-password'))
    # Certificate trust bypass is restricted to in-Pod loopback, never remote clients.
    result = subprocess.run([SQLCMD, '-S', 'localhost,1433', '-U', user,
                             '-C', '-b', '-V', '11', '-x', '-l', '5',
                             '-t', str(timeout), '-h', '-1', '-W'],
                            input='SET NOCOUNT ON;\n' + statement + '\nGO\n',
                            text=True, capture_output=True, env=env, timeout=timeout+10)
    if result.returncode:
        # Do not emit SQL text/output that may include credentials from a failed batch.
        codes = sorted(set(re.findall(r'Msg (\d+), Level \d+, State \d+', result.stdout + result.stderr)))
        detail = f" (SQL error codes: {', '.join(codes)})" if codes else ''
        raise RuntimeError('SQL operation failed' + detail + '; verify credentials, permissions and declared configuration')
    return result.stdout.strip()


def ensure_login(name, secret):
    sql(f"IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name={literal(name)}) "
        f"CREATE LOGIN {ident(name)} WITH PASSWORD={literal(secret)}, CHECK_POLICY=ON, CHECK_EXPIRATION=OFF;")
    sql('SELECT 1;', user=name, secret=secret)


def provision():
    config = json.loads(Path('/config/bootstrap.json').read_text())
    for name, key in [('hf_probe', 'probe-password'), ('hf_backup', 'backup-password'), ('hf_metrics', 'metrics-password')]:
        if name == 'hf_backup' and not config['backupEnabled']:
            continue
        if name == 'hf_metrics' and not config['metricsEnabled']:
            continue
        ensure_login(name, password(key))
    if config['metricsEnabled']:
        sql('GRANT VIEW SERVER PERFORMANCE STATE TO [hf_metrics]; GRANT VIEW ANY DEFINITION TO [hf_metrics];')
    for i, db in enumerate(config['databases']):
        name = db['name']
        sql(f"IF DB_ID({literal(name)}) IS NULL BEGIN CREATE DATABASE {ident(name)}; "
            f"ALTER DATABASE {ident(name)} SET RECOVERY {db.get('recoveryModel', 'SIMPLE')}; END;")
        user = db.get('username', '')
        if user:
            secret = Path(f'/applications/{i}/password').read_text().rstrip('\r\n')
            ensure_login(user, secret)
            sql(f"USE {ident(name)}; IF USER_ID({literal(user)}) IS NULL CREATE USER {ident(user)} FOR LOGIN {ident(user)};")
            for role in db.get('roles', ['db_datareader', 'db_datawriter', 'db_ddladmin']):
                sql(f'USE {ident(name)}; ALTER ROLE {ident(role)} ADD MEMBER {ident(user)};')
    for name in config['backupDatabases'] if config['backupEnabled'] else []:
        sql(f"USE {ident(name)}; IF USER_ID(N'hf_backup') IS NULL CREATE USER [hf_backup] FOR LOGIN [hf_backup]; "
            'ALTER ROLE [db_backupoperator] ADD MEMBER [hf_backup];')
    sql("IF OBJECT_ID(N'master.dbo.helmforge_bootstrap') IS NULL CREATE TABLE master.dbo.helmforge_bootstrap "
        '(script_name nvarchar(400) PRIMARY KEY, sha256 char(64) NOT NULL, applied_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME());')
    for script in sorted(Path('/initdb').glob('*/*.sql')):
        name = str(script.relative_to('/initdb'))
        digest = hashlib.sha256(script.read_bytes()).hexdigest()
        old = sql(f'SELECT sha256 FROM master.dbo.helmforge_bootstrap WHERE script_name={literal(name)};')
        if old:
            if old != digest:
                raise RuntimeError('Previously applied initialization script changed; publish a new script name')
            continue
        # GO-separated batches remain in one sqlcmd connection/transaction.
        sql('SET XACT_ABORT ON; BEGIN TRANSACTION;\nGO\n' + script.read_text() +
            f'\nGO\nINSERT master.dbo.helmforge_bootstrap(script_name,sha256) VALUES({literal(name)},{literal(digest)}); COMMIT;', timeout=300)
    READY.write_text('ready\n')
    print('HelmForge SQL provisioning complete', flush=True)


def main():
    READY.unlink(missing_ok=True)
    env = dict(os.environ, MSSQL_SA_PASSWORD=password('sa-password'))
    if env.get('HF_PRODUCT_KEY_FILE'):
        env['MSSQL_PID'] = Path(env['HF_PRODUCT_KEY_FILE']).read_text().strip()
    engine = subprocess.Popen(['/opt/mssql/bin/launch_sqlservr.sh', '/opt/mssql/bin/sqlservr'], env=env, start_new_session=True)
    stopping = False

    def stop(signum, frame):
        nonlocal stopping
        stopping = True
        READY.unlink(missing_ok=True)
        try:
            os.killpg(engine.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        for _ in range(180):
            if engine.poll() is not None or stopping:
                return engine.wait()
            try:
                sql('SELECT 1;', timeout=5)
                break
            except (RuntimeError, subprocess.TimeoutExpired):
                time.sleep(2)
        else:
            raise RuntimeError('SQL bootstrap did not become reachable with the supplied administrator credential')
        provision()
        return engine.wait()
    except Exception as error:
        print(f'HelmForge provisioning stopped: {error}', file=sys.stderr, flush=True)
        stop(signal.SIGTERM, None)
        try:
            engine.wait(timeout=90)
        except subprocess.TimeoutExpired:
            os.killpg(engine.pid, signal.SIGKILL)
            engine.wait()
        return 1


if __name__ == '__main__':
    sys.exit(main())
