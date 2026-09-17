// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 120000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pod = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items
  .find(p => !p.metadata.deletionTimestamp && p.spec.containers.some(c => c.name === 'chiefonboarding')
    && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True'));
assert.ok(pod);
assert.match(pod.spec.containers.find(c => c.name === 'chiefonboarding').image, /:v2\.5\.0$/);
console.log(run(['exec', pod.metadata.name, '-c', 'chiefonboarding', '--', 'uv', 'run', 'python', '-c', `
import os, time, urllib.request
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'back.settings')
import django
django.setup()
from django.conf import settings
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
executor = MigrationExecutor(connection)
assert not executor.migration_plan(executor.loader.graph.leaf_nodes()), 'Unapplied migrations'
from django.test import Client
response = Client(HTTP_HOST='localhost').get('/')
assert response.status_code in (200, 301, 302), response.status_code
from django_q.tasks import async_task, result
task = async_task('operator.add', 20, 22)
deadline = time.time() + 60
while time.time() < deadline and result(task) is None:
    time.sleep(1)
assert result(task) == 42, 'Background worker did not execute the task'
if settings.AWS_STORAGE_BUCKET_NAME:
    from misc.s3 import S3
    assert settings.AWS_USE_PRESIGNED_UPLOADS is False
    storage = S3()
    key = 'helmforge-runtime/server-upload.txt'
    payload = b'chiefonboarding-server-upload-roundtrip'
    try:
        storage.put_file(key, payload)
        assert urllib.request.urlopen(storage.get_file(key), timeout=15).read() == payload
    finally:
        storage.delete_file(key)
    print('PASS server-side S3 upload, signed download and deletion')
print('PASS ChiefOnboarding migrations, HTTP and background task execution')
`]).trim());
