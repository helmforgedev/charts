// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items
  .filter(p => !p.metadata.deletionTimestamp && p.spec.containers.some(c => c.name === 'docmost')
    && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True'));
assert.ok(pods.length);
for (const pod of pods) {
  assert.match(pod.spec.containers.find(c => c.name === 'docmost').image, /:0\.96\.0$/);
  console.log(run(['exec', pod.metadata.name, '-c', 'docmost', '--', 'node', '-e', `
    const assert = require('node:assert/strict');
    process.chdir('/app/apps/server');
    const {createRequire} = require('node:module');
    const req = createRequire('/app/apps/server/package.json');
    (async () => {
      assert.equal((await fetch('http://127.0.0.1:3000/api/health')).status, 200);
      const {EncryptionService} = req('./dist/integrations/encryption/encryption.service.js');
      const encryption = new EncryptionService({getAppSecret: () => process.env.APP_SECRET});
      const marker = 'helmforge-docmost-storage-fixture';
      const encrypted = encryption.encrypt(marker);
      assert.notEqual(encrypted, marker);
      assert.equal(encryption.decrypt(encrypted), marker);
      let driver;
      if (process.env.STORAGE_DRIVER === 's3') {
        const {S3Driver} = req('./dist/integrations/storage/drivers/s3.driver.js');
        driver = new S3Driver({region: process.env.AWS_S3_REGION, bucket: process.env.AWS_S3_BUCKET,
          endpoint: process.env.AWS_S3_ENDPOINT, forcePathStyle: process.env.AWS_S3_FORCE_PATH_STYLE === 'true',
          credentials: {accessKeyId: process.env.AWS_S3_ACCESS_KEY_ID, secretAccessKey: process.env.AWS_S3_SECRET_ACCESS_KEY}});
      } else {
        const {LocalDriver} = req('./dist/integrations/storage/drivers/local.driver.js');
        driver = new LocalDriver({storagePath: '/app/data/storage'});
      }
      const key = 'helmforge-runtime/' + process.env.HOSTNAME + '.txt';
      try {
        await driver.upload(key, Buffer.from(encrypted));
        assert.equal(encryption.decrypt((await driver.read(key)).toString()), marker);
      } finally { await driver.delete(key); }
      console.log('PASS Docmost health, APP_SECRET encryption and ' + process.env.STORAGE_DRIVER + ' upload/read/delete');
      process.exit(0);
    })().catch(error => {console.error(error); process.exit(1);});
  `]).trim());
}
