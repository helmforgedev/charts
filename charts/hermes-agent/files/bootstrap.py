# SPDX-License-Identifier: Apache-2.0
"""Initialize only the release's data volume; reconcile declared configuration."""
import os
import subprocess
from pathlib import Path

os.umask(0o077)
home = Path('/opt/data')
if (home / '.helmforge-restore-incomplete').exists():
    raise SystemExit('Restore is incomplete; refusing to start the agent')
for directory in ('workspace', 'home', 'memories', 'skills', 'sessions', 'cron', 'logs', 'profiles'):
    target = home / directory
    if target.is_symlink():
        raise SystemExit('Refusing a symlinked state directory')
    target.mkdir(exist_ok=True)
for name in ('config.yaml', 'SOUL.md'):
    source = Path('/helmforge') / name
    target = home / name
    if target.is_symlink():
        raise SystemExit('Refusing a symlinked configuration target')
    if name == 'SOUL.md' and not source.read_text().strip():
        continue
    if os.environ['CONFIG_POLICY'] == 'managed' or not target.exists():
        temporary = home / ('.helmforge-' + name)
        if temporary.is_symlink():
            raise SystemExit('Refusing a symlinked temporary configuration path')
        temporary.write_bytes(source.read_bytes())
        temporary.chmod(0o600)
        temporary.replace(target)
subprocess.run(['/opt/hermes/.venv/bin/python', '/opt/hermes/tools/skills_sync.py'], check=True)
print('Hermes state and declared configuration initialized')
