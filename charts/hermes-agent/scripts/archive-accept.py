# SPDX-License-Identifier: Apache-2.0
"""Exercise recovery failure boundaries in disposable directories, never live state."""
import json
import os
import pathlib
import shutil
import sqlite3
import tempfile


def validate(module):
    temporary = pathlib.Path(tempfile.mkdtemp(prefix='hf-archive-', dir='/tmp'))
    try:
        module.ROOT = temporary / 'state'
        module.WORK = temporary / 'work'
        module.ROOT.mkdir()
        module.WORK.mkdir()
        (module.ROOT / 'config.yaml').write_text('model: test\n')
        with sqlite3.connect(module.ROOT / 'state.db') as database:
            database.execute('create table proof (value text)')
            database.execute("insert into proof values ('restorable')")
        with sqlite3.connect(module.ROOT / 'provider.store') as database:
            database.execute('create table provider_state (value text)')
        os.environ['HERMES_IMAGE'] = 'official-image-contract-test'
        os.environ['RESTORE_MANIFEST_KEY'] = 'test/manifest.json'
        os.environ['MAX_ARCHIVE_BYTES'] = '10485760'
        def fails(action):
            try:
                action()
                raise AssertionError('Invalid archive operation unexpectedly succeeded')
            except (RuntimeError, OSError):
                pass
        def clear_work():
            shutil.rmtree(module.WORK)
            module.WORK.mkdir()
        snapshot = module.native._safe_copy_db
        try:
            module.native._safe_copy_db = lambda *_args, **_kwargs: False
            fails(module.backup)
            assert not (module.WORK / 'manifest.json').exists()
        finally:
            module.native._safe_copy_db = snapshot
        clear_work()
        blocked = module.ROOT / 'unreadable.txt'
        blocked.write_text('must-not-be-silently-skipped')
        blocked.chmod(0)
        fails(module.backup)
        assert not (module.WORK / 'manifest.json').exists()
        blocked.chmod(0o600)
        blocked.unlink()
        clear_work()
        nested = module.ROOT / 'nested'
        nested.mkdir()
        (nested / 'payload.txt').write_text('inside')
        outside = temporary / 'outside'
        outside.mkdir()
        (outside / 'payload.txt').write_text('must-not-be-archived')
        original_open = module.os.open
        def replaced_directory(path, flags, *args, **kwargs):
            if path == 'nested' and kwargs.get('dir_fd') is not None:
                nested.rename(module.ROOT / 'saved')
                nested.symlink_to(outside, target_is_directory=True)
            return original_open(path, flags, *args, **kwargs)
        descriptors = len(list(pathlib.Path('/proc/self/fd').iterdir()))
        try:
            module.os.open = replaced_directory
            fails(module.backup)
            assert not (module.WORK / 'manifest.json').exists()
            assert len(list(pathlib.Path('/proc/self/fd').iterdir())) == descriptors
        finally:
            module.os.open = original_open
            nested.unlink()
            (module.ROOT / 'saved').rename(nested)
        clear_work()
        print('PASS intermediate-directory replacement is rejected without leaking descriptors')
        module.backup()
        manifest = json.loads((module.WORK / 'manifest.json').read_text())
        assert manifest['files']['provider.store']['sqlite'] is True
        module.verify_archive(manifest, module.WORK / 'backup.zip')
        with (module.WORK / 'backup.zip').open('ab') as archive:
            archive.write(b'corruption')
        fails(lambda: module.verify_archive(manifest, module.WORK / 'backup.zip'))
        fails(module.prepare_restore)
        assert not (module.ROOT / '.helmforge-restore-incomplete').exists()
        for name in ('../escape', '/absolute', 'parent/../escape', 'C:/escape', 'double//entry', '_external/provider'):
            fails(lambda: module.safe_name(name))
        print('PASS failed SQLite snapshot/unreadable file cannot publish success; corrupted archives, unsafe paths and nonempty targets rejected')
    finally:
        shutil.rmtree(temporary)
