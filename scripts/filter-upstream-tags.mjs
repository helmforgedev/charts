// SPDX-License-Identifier: Apache-2.0
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

export function filterDistributionTags(repository, tags) {
  const standaloneMatterbridge = repository.replace(/^docker\.io\//, '') === 'luligu/matterbridge';
  // This repository also publishes Home Assistant add-on images under year-based tags.
  return tags.filter(tag => !standaloneMatterbridge || !/^v?\d{4}\./.test(tag));
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const repository = process.argv[2];
  if (!repository) throw new Error('Image repository is required');
  const tags = readFileSync(0, 'utf8').split(/\r?\n/).filter(Boolean);
  process.stdout.write(filterDistributionTags(repository, tags).join('\n') + '\n');
}
