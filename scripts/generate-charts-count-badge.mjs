import { mkdir, readdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

const repoRoot = process.argv[2] ?? '.';
const outputPath = process.argv[3] ?? 'badges/charts-count.json';
const chartsDir = join(repoRoot, 'charts');

const entries = await readdir(chartsDir, { withFileTypes: true });
let count = 0;

for (const entry of entries) {
  if (!entry.isDirectory()) {
    continue;
  }

  const chartFiles = await readdir(join(chartsDir, entry.name));
  if (chartFiles.includes('Chart.yaml')) {
    count += 1;
  }
}

const badge = {
  schemaVersion: 1,
  label: 'Charts',
  message: String(count),
  color: 'blue',
};

await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, `${JSON.stringify(badge, null, 2)}\n`);
