// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 30000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp
  && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True')
  && p.spec.containers.some(c => c.name === 'medikeep'));
assert.ok(pod, 'Ready MediKeep pod required');
const container = pod.spec.containers.find(c => c.name === 'medikeep');
assert.match(container.image, /:v0\.70\.0$/);
const ssoOnly = ['true', '1', 'yes', 'on'].includes(
  container.env.find(e => e.name === 'SSO_ONLY_MODE')?.value?.toLowerCase());
const result = run(['exec', pod.metadata.name, '-c', 'medikeep', '--', 'python', '-c', `
import json, urllib.request, urllib.error
base = 'http://127.0.0.1:8000'
assert urllib.request.urlopen(base + '/health', timeout=10).status == 200
config = json.load(urllib.request.urlopen(base + '/api/v1/sso/config', timeout=10))
assert config['sso_only'] is ${ssoOnly ? 'True' : 'False'}, config
if config['sso_only']:
    assert config['enabled'] is True
    req = urllib.request.Request(base + '/api/v1/auth/login', data=b'username=smoke&password=invalid', headers={'Content-Type':'application/x-www-form-urlencoded'})
    try:
        urllib.request.urlopen(req, timeout=10)
        raise AssertionError('Password login must be disabled')
    except urllib.error.HTTPError as error:
        assert error.code == 403, error.code
print('MediKeep 0.70.0 health and authentication mode verified; sso_only=' + str(config['sso_only']))
`]);
console.log(result.trim());
