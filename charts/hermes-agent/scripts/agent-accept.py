# SPDX-License-Identifier: Apache-2.0
import json
import os
import urllib.error
import urllib.request
import uuid
from pathlib import Path

url = 'http://127.0.0.1:8642'
key = os.environ['API_SERVER_KEY']
for supplied in ('', 'deliberately-wrong-token'):
    try:
        urllib.request.urlopen(urllib.request.Request(url + '/v1/models', headers={'Authorization': 'Bearer ' + supplied}), timeout=10)
        raise AssertionError('Unauthenticated request accepted')
    except urllib.error.HTTPError as error:
        assert error.code in (401, 403), error.code
print('PASS missing and incorrect API credentials rejected')
prompt = os.environ.get('TEST_PROMPT', 'HF_MEMORY_STORE')
session_id = ('hf-memory-fresh-' + uuid.uuid4().hex if prompt == 'HF_MEMORY_CHECK'
              else 'hf-mvp-persistent-session')
headers = {'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json', 'X-Hermes-Session-Id': session_id}
payload = {'model': 'hermes-agent', 'stream': False, 'messages': [{'role': 'user', 'content': prompt}]}
with urllib.request.urlopen(urllib.request.Request(url + '/v1/chat/completions', data=json.dumps(payload).encode(), headers=headers), timeout=100) as response:
    answer = json.load(response)['choices'][0]['message']['content']
expected = {'HF_MEMORY_STORE': 'HF_MEMORY_STORED', 'HF_HISTORY_CHECK': 'HF_HISTORY_RESTORED', 'HF_MEMORY_CHECK': 'HF_MEMORY_RESTORED'}[prompt]
assert expected in answer, answer
assert 'HF_HERMES_PERSISTENT_MEMORY' in Path('/opt/data/memories/MEMORY.md').read_text()
print('PASS real Hermes agent turn, memory tool and persisted memory: ' + expected)
