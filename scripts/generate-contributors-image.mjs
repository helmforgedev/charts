import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

const [repo = 'helmforgedev/charts', outputPath = 'badges/contributors.svg'] = process.argv.slice(2);
const token = process.env.GITHUB_TOKEN ?? process.env.GH_TOKEN;
const maxContributors = Number.parseInt(process.env.CONTRIBUTORS_LIMIT ?? '24', 10);
const excludedLogins = new Set(
  (process.env.CONTRIBUTORS_EXCLUDE ?? 'cursoragent,github-actions[bot],dependabot[bot],renovate[bot]')
    .split(',')
    .map((login) => login.trim().toLowerCase())
    .filter(Boolean),
);

if (!token) {
  throw new Error('GITHUB_TOKEN or GH_TOKEN is required to fetch GitHub commit authors.');
}

const [owner, name] = repo.split('/');
const headers = {
  Accept: 'application/vnd.github+json',
  Authorization: `Bearer ${token}`,
  'User-Agent': 'helmforge-contributors-badge',
};

function escapeXml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function isAutomation(login) {
  const normalized = login.toLowerCase();
  return excludedLogins.has(normalized) || normalized.endsWith('[bot]');
}

async function graphql(query, variables) {
  const response = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers,
    body: JSON.stringify({ query, variables }),
  });

  if (!response.ok) {
    throw new Error(`GitHub GraphQL request failed: ${response.status} ${response.statusText}`);
  }

  const payload = await response.json();

  if (payload.errors?.length) {
    throw new Error(`GitHub GraphQL error: ${payload.errors.map((error) => error.message).join('; ')}`);
  }

  return payload.data;
}

async function fetchBuffer(url) {
  const response = await fetch(url, { headers });

  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`);
  }

  return Buffer.from(await response.arrayBuffer());
}

async function fetchContributors() {
  const contributors = new Map();
  let cursor = null;

  do {
    const data = await graphql(
      `query($owner: String!, $name: String!, $cursor: String) {
        repository(owner: $owner, name: $name) {
          defaultBranchRef {
            target {
              ... on Commit {
                history(first: 100, after: $cursor) {
                  pageInfo {
                    hasNextPage
                    endCursor
                  }
                  nodes {
                    authors(first: 20) {
                      nodes {
                        user {
                          login
                          avatarUrl
                          url
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }`,
      { owner, name, cursor },
    );

    const history = data.repository.defaultBranchRef.target.history;

    for (const commit of history.nodes) {
      const seenInCommit = new Set();

      for (const author of commit.authors.nodes) {
        const user = author.user;

        if (!user || isAutomation(user.login) || seenInCommit.has(user.login)) {
          continue;
        }

        seenInCommit.add(user.login);

        const current = contributors.get(user.login) ?? {
          login: user.login,
          avatarUrl: user.avatarUrl,
          url: user.url,
          contributions: 0,
        };

        current.contributions += 1;
        contributors.set(user.login, current);
      }
    }

    cursor = history.pageInfo.hasNextPage ? history.pageInfo.endCursor : null;
  } while (cursor);

  return [...contributors.values()].sort(
    (left, right) => right.contributions - left.contributions || left.login.localeCompare(right.login),
  );
}

const contributors = (await fetchContributors()).slice(0, maxContributors);

const avatarSize = 64;
const gap = 12;
const labelHeight = 22;
const padding = 12;
const columns = Math.min(6, Math.max(1, contributors.length));
const rows = Math.max(1, Math.ceil(contributors.length / columns));
const width = padding * 2 + columns * avatarSize + (columns - 1) * gap;
const height = padding * 2 + rows * (avatarSize + labelHeight + gap) - gap;

const avatarImages = await Promise.all(
  contributors.map(async (contributor) => {
    const image = await fetchBuffer(`${contributor.avatarUrl}&s=${avatarSize * 2}`);
    return {
      ...contributor,
      image: `data:image/png;base64,${image.toString('base64')}`,
    };
  }),
);

const items = avatarImages
  .map((contributor, index) => {
    const column = index % columns;
    const row = Math.floor(index / columns);
    const x = padding + column * (avatarSize + gap);
    const y = padding + row * (avatarSize + labelHeight + gap);
    const clipId = `avatar-${index}`;
    const login = escapeXml(contributor.login);

    return `
  <a href="${escapeXml(contributor.url)}" target="_blank">
    <title>${login}</title>
    <clipPath id="${clipId}">
      <circle cx="${x + avatarSize / 2}" cy="${y + avatarSize / 2}" r="${avatarSize / 2}" />
    </clipPath>
    <image href="${contributor.image}" x="${x}" y="${y}" width="${avatarSize}" height="${avatarSize}" clip-path="url(#${clipId})" />
    <text x="${x + avatarSize / 2}" y="${y + avatarSize + 16}" text-anchor="middle">${login}</text>
  </a>`;
  })
  .join('');

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="title desc">
  <title id="title">Contributors for ${escapeXml(repo)}</title>
  <desc id="desc">Contributor avatars generated from GitHub commit authors and coauthors.</desc>
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

console.log(`Generated ${outputPath} with ${contributors.length} contributors.`);
