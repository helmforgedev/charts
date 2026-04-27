import { readFile, writeFile } from 'node:fs/promises';

const [indexPath = 'index.yaml', invalidVersionsPath = 'scripts/artifacthub-invalid-versions.json'] =
  process.argv.slice(2);

const index = await readFile(indexPath, 'utf8');
const invalidVersions = JSON.parse(await readFile(invalidVersionsPath, 'utf8'));
const invalid = new Set(invalidVersions.map((entry) => `${entry.name}@${entry.version}`));

const lines = index.split(/\r?\n/);
const output = [];
const removed = [];

let i = 0;
let inEntries = false;

function chartHeader(line) {
  const match = line.match(/^  ([A-Za-z0-9_.-]+):\s*$/);
  return match?.[1] ?? null;
}

function entryVersion(block) {
  for (const line of block) {
    const match = line.match(/^    version:\s*"?([^"\s]+)"?\s*$/);
    if (match) {
      return match[1];
    }
  }

  return null;
}

while (i < lines.length) {
  const line = lines[i];

  if (line === 'entries:') {
    inEntries = true;
    output.push(line);
    i += 1;
    continue;
  }

  if (!inEntries) {
    output.push(line);
    i += 1;
    continue;
  }

  const chart = chartHeader(line);

  if (!chart) {
    output.push(line);
    i += 1;
    continue;
  }

  const chartLines = [line];
  i += 1;

  while (i < lines.length && !chartHeader(lines[i]) && lines[i] !== 'generated:') {
    if (!lines[i].startsWith('  - ')) {
      chartLines.push(lines[i]);
      i += 1;
      continue;
    }

    const entry = [lines[i]];
    i += 1;

    while (
      i < lines.length &&
      !lines[i].startsWith('  - ') &&
      !chartHeader(lines[i]) &&
      lines[i] !== 'generated:'
    ) {
      entry.push(lines[i]);
      i += 1;
    }

    const version = entryVersion(entry);
    const key = `${chart}@${version}`;

    if (invalid.has(key)) {
      removed.push(key);
      continue;
    }

    chartLines.push(...entry);
  }

  if (chartLines.length > 1) {
    output.push(...chartLines);
  }
}

await writeFile(indexPath, output.join('\n'));

console.log(`Removed ${removed.length} invalid Artifact Hub entr${removed.length === 1 ? 'y' : 'ies'}.`);
for (const key of removed) {
  console.log(`- ${key}`);
}

const missing = [...invalid].filter((key) => !removed.includes(key));
if (missing.length > 0) {
  console.log('Configured invalid entries not present in index:');
  for (const key of missing) {
    console.log(`- ${key}`);
  }
}
