# SPDX-License-Identifier: Apache-2.0
"""Run the upstream foreground process with bundled browser discovery."""
import os
import sys
from pathlib import Path

os.umask(0o077)
if not os.environ.get('AGENT_BROWSER_EXECUTABLE_PATH'):
    directory = Path(os.environ.get('PLAYWRIGHT_BROWSERS_PATH', '/opt/hermes/.playwright'))
    names = {'chrome', 'chromium', 'chrome-headless-shell', 'headless_shell', 'chromium-browser'}
    if directory.is_dir():
        for candidate in sorted(directory.rglob('*')):
            if candidate.name in names and candidate.is_file() and os.access(candidate, os.X_OK):
                os.environ['AGENT_BROWSER_EXECUTABLE_PATH'] = str(candidate)
                break
if not sys.argv[1:]:
    raise SystemExit('An explicit foreground command is required')
os.execv(sys.argv[1], sys.argv[1:])
