import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

const [repo = 'helmforgedev/charts', outputPath = 'badges/contributors.svg'] = process.argv.slice(2);
const token = process.env.GITHUB_TOKEN;
const maxContributors = Number.parseInt(process.env.CONTRIBUTORS_LIMIT ?? '24', 10);

const headers = {
  Accept: 'application/vnd.github+json',
  'User-Agent': 'helmforge-contributors-badge',
};

if (token) {
  headers.Authorization = `Bearer ${token}`;
}

async function fetchBuffer(url) {
  const response = await fetch(url, { headers });

  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`);
  }

  return Buffer.from(await response.arrayBuffer());
}

const contributorsResponse = await fetch(`https://api.github.com/repos/${repo}/contributors?per_page=100`, { headers });

if (!contributorsResponse.ok) {
  throw new Error(
    `Failed to fetch contributors for ${repo}: ${contributorsResponse.status} ${contributorsResponse.statusText}`,
  );
}

const contributors = await contributorsResponse.json();
const humans = contributors.filter((contributor) => !contributor.login.endsWith('[bot]'));
const selected = (humans.length > 0 ? humans : contributors).slice(0, maxContributors);

const avatarSize = 64;
const gap = 12;
const labelHeight = 22;
const padding = 12;
const columns = Math.min(6, Math.max(1, selected.length));
const rows = Math.max(1, Math.ceil(selected.length / columns));
const width = padding * 2 + columns * avatarSize + (columns - 1) * gap;
const height = padding * 2 + rows * (avatarSize + labelHeight + gap) - gap;

const avatarImages = await Promise.all(
  selected.map(async (contributor) => {
    const image = await fetchBuffer(`${contributor.avatar_url}&s=${avatarSize * 2}`);
    return {
      ...contributor,
      image: `data:image/png;base64,${image.toString('base64')}`,
    };
  }),
);

const escapedRepo = repo.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const items = avatarImages
  .map((contributor, index) => {
    const column = index % columns;
    const row = Math.floor(index / columns);
    const x = padding + column * (avatarSize + gap);
    const y = padding + row * (avatarSize + labelHeight + gap);
    const clipId = `avatar-${index}`;
    const login = contributor.login
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

    return `
  <a href="${contributor.html_url}" target="_blank">
    <clipPath id="${clipId}">
      <circle cx="${x + avatarSize / 2}" cy="${y + avatarSize / 2}" r="${avatarSize / 2}" />
    </clipPath>
    <image href="${contributor.image}" x="${x}" y="${y}" width="${avatarSize}" height="${avatarSize}" clip-path="url(#${clipId})" />
    <text x="${x + avatarSize / 2}" y="${y + avatarSize + 16}" text-anchor="middle">${login}</text>
  </a>`;
  })
  .join('');

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="title desc">
  <title id="title">Contributors for ${escapedRepo}</title>
  <desc id="desc">Dynamic contributor avatars generated from GitHub contributors.</desc>
  <style>
    text {
      fill: #24292f;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      font-size: 11px;
      font-weight: 600;
    }
    @media (prefers-color-scheme: dark) {
      text { fill: #f0f6fc; }
    }
  </style>${items}
</svg>
`;

await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, svg);
