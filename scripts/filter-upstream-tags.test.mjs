// SPDX-License-Identifier: Apache-2.0
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {filterDistributionTags} from './filter-upstream-tags.mjs';

test('excludes Home Assistant tags while retaining future standalone major releases', () => {
  for (const repository of ['docker.io/luligu/matterbridge', 'luligu/matterbridge']) {
    assert.deepEqual(filterDistributionTags(repository, ['3.10.7', '2026.9.1', '3.10.8', 'v2027.1.0', '4.0.0']), ['3.10.7', '3.10.8', '4.0.0']);
  }
});
test('preserves calendar versions for other distributions', () => {
  assert.deepEqual(filterDistributionTags('docker.io/cloudflare/cloudflared', ['2026.8.3']), ['2026.8.3']);
});
test('filters newline-delimited registry output through the CLI', () => {
  const script = fileURLToPath(new URL('./filter-upstream-tags.mjs', import.meta.url));
  const output = execFileSync(process.execPath, [script, 'luligu/matterbridge'], {
    input: '3.10.8\r\n2026.9.1\r\n\r\n', encoding: 'utf8',
  });
  assert.equal(output, '3.10.8\n');
});
