// SPDX-License-Identifier: Apache-2.0
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

export function filterDistributionTags(repository, tags) {
  const normalizedRepository = repository.replace(/^docker\.io\//, '');
  const standaloneMatterbridge = normalizedRepository === 'luligu/matterbridge';
  const valkey = normalizedRepository === 'valkey/valkey';
  // This repository also publishes Home Assistant add-on images under year-based tags.
  // Valkey's two-component aliases can point to release candidates before the
  // corresponding stable patch release exists, so only accept complete tags.
  return tags.filter(tag => (!standaloneMatterbridge || !/^v?\d{4}\./.test(tag))
    && (!valkey || /^v?\d+\.\d+\.\d+(?:[-+].*)?$/.test(tag)));
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const repository = process.argv[2];
  if (!repository) throw new Error('Image repository is required');
  const tags = readFileSync(0, 'utf8').split(/\r?\n/).filter(Boolean);
  process.stdout.write(filterDistributionTags(repository, tags).join('\n') + '\n');
}
