# SPDX-License-Identifier: Apache-2.0
"""Strict root-scoped snapshots and offline restore; never run native service revival."""
import hashlib
import json
import os
import secrets
import shutil
import stat
import sys
import zipfile
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

from hermes_cli import backup as native

CHUNK = 1024 * 1024
RUNTIME = {'gateway_state.json', 'gateway.pid', 'cron.pid', 'gateway.lock', 'gateway.sock', 'processes.json'}
ROOT = Path(os.environ.get('TARGET_HOME', os.environ.get('HERMES_HOME', '/opt/data')))
WORK = Path('/work')


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest_file(path):
    digest = hashlib.sha256()
    size = 0
    with path.open('rb') as stream:
        while chunk := stream.read(CHUNK):
            digest.update(chunk)
            size += len(chunk)
    return digest.hexdigest(), size


def safe_name(name):
    path = PurePosixPath(name)
    require(isinstance(name, str) and name and not path.is_absolute(), 'Invalid archive path')
    require('\\' not in name and ':' not in name and '\x00' not in name, 'Invalid archive path')
    require(all(part not in ('', '.', '..') for part in name.split('/')), 'Ambiguous archive path')
    require(path.parts[0] != '_external', 'External state is outside this backup contract')
    return path


def excluded(relative):
    return (native._should_exclude(relative) or relative.name in RUNTIME
            or (relative.name.startswith('gateway.loop-tick.') and relative.name.endswith('.sock'))
            or relative.name.startswith('.helmforge-'))


def enumerate_files():
    def fail_walk(error):
        raise error
    files = []
    for directory, children, names in os.walk(ROOT, followlinks=False, onerror=fail_walk):
        parent = Path(directory)
        children[:] = sorted(name for name in children
                             if not (parent / name).is_symlink() and not excluded((parent / name).relative_to(ROOT)))
        for name in sorted(names):
            path = parent / name
            relative = path.relative_to(ROOT)
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode) or excluded(relative):
                continue
            require(stat.S_ISREG(info.st_mode), 'Unsupported non-regular state file')
            safe_name(relative.as_posix())
            require(path.resolve().is_relative_to(ROOT.resolve()), 'State path escapes the managed root')
            files.append(relative)
    return files


def verify_archive(manifest, archive, destination=None):
    require(manifest.get('formatVersion') == 1, 'Unsupported backup format')
    expected = manifest.get('files')
    require(isinstance(expected, dict) and 0 < len(expected) <= 100000, 'Invalid file inventory')
    require('config.yaml' in expected and 'state.db' in expected, 'Required Hermes state is missing')
    require(manifest.get('archive', {}).get('name') == 'backup.zip', 'Invalid archive name')
    digest, size = digest_file(archive)
    require(size == manifest['archive']['bytes'] and digest == manifest['archive']['sha256'], 'Archive checksum/size mismatch')
    max_expanded = int(os.environ.get('MAX_EXPANDED_BYTES', '21474836480'))
    with zipfile.ZipFile(archive) as bundle:
        infos = bundle.infolist()
        require(len(infos) == len(expected) and {entry.filename for entry in infos} == set(expected), 'Archive inventory mismatch')
        require(sum(entry.file_size for entry in infos) <= max_expanded, 'Expanded archive exceeds configured limit')
        for entry in infos:
            path = safe_name(entry.filename)
            mode = entry.external_attr >> 16
            require(stat.S_ISREG(mode) and not entry.flag_bits & 1, 'Archive contains a special or encrypted entry')
            require(entry.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), 'Unsupported compression')
            metadata = expected[entry.filename]
            require(entry.file_size == metadata['bytes'], 'Member size mismatch')
            require(metadata['mode'] in (0o600, 0o700), 'Unsupported member permissions')
            for parent in path.parents:
                require(parent.as_posix() not in expected, 'File/directory conflict')
            output = None
            if destination:
                target = destination.joinpath(*path.parts)
                target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                output = target.open('xb')
            digest = hashlib.sha256()
            count = 0
            try:
                with bundle.open(entry) as source:
                    while chunk := source.read(CHUNK):
                        count += len(chunk)
                        require(count <= metadata['bytes'], 'Member exceeds declared size')
                        digest.update(chunk)
                        if output:
                            output.write(chunk)
            finally:
                if output:
                    output.close()
            require(count == metadata['bytes'] and digest.hexdigest() == metadata['sha256'], 'Member checksum mismatch')
            if destination:
                target.chmod(metadata['mode'])
                if metadata.get('sqlite', False) or target.suffix in ('.db', '.sqlite', '.sqlite3'):
                    require(native.verify_sqlite_integrity(target, max_bytes=0)['valid'], 'Restored SQLite integrity check failed')


@contextmanager
def open_state_file(relative):
    """Walk from an open root, rejecting symlinks in every path component."""
    parts = safe_name(relative.as_posix()).parts
    directory = os.open(ROOT, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    descriptor = None
    try:
        for part in parts[:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
            os.close(directory)
            directory = child
        descriptor = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW, dir_fd=directory)
        require(stat.S_ISREG(os.fstat(descriptor).st_mode), 'State file changed during backup')
        require(Path(f'/proc/self/fd/{descriptor}').resolve().is_relative_to(ROOT.resolve()), 'Opened state file escapes root')
        yield descriptor
    finally:
        if descriptor is not None:
            os.close(descriptor)
        os.close(directory)


def backup():
    require(ROOT.is_dir() and not ROOT.is_symlink(), 'Invalid state directory')
    require((ROOT / 'config.yaml').is_file() and (ROOT / 'state.db').is_file(), 'Agent state is not initialized')
    require(not list(WORK.iterdir()), 'Backup staging must be empty')
    run = datetime.now(timezone.utc).strftime('hermes-%Y%m%dT%H%M%SZ-') + secrets.token_hex(8)
    archive = WORK / 'backup.zip'
    inventory = {}
    with native._backup_operation_lock(ROOT):
        files = enumerate_files()
        with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, allowZip64=True) as bundle:
            for relative in files:
                with open_state_file(relative) as descriptor:
                    info = os.fstat(descriptor)
                    signature = os.read(descriptor, 16)
                    os.lseek(descriptor, 0, os.SEEK_SET)
                    is_sqlite = relative.suffix in ('.db', '.sqlite', '.sqlite3') or signature == b'SQLite format 3\x00'
                    snapshot = WORK / 'snapshot.db'
                    if is_sqlite:
                        pinned = Path(f'/proc/self/fd/{descriptor}')
                        require(native._safe_copy_db(pinned, snapshot), 'Native SQLite snapshot failed')
                        require(pinned.resolve().is_relative_to(ROOT.resolve()), 'State database moved outside root')
                        require(native.verify_sqlite_integrity(snapshot, max_bytes=0)['valid'], 'SQLite snapshot integrity check failed')
                        archive_descriptor = os.open(snapshot, os.O_RDONLY | os.O_NOFOLLOW)
                    else:
                        archive_descriptor = os.dup(descriptor)
                    mode = 0o700 if info.st_mode & 0o111 and not is_sqlite else 0o600
                    entry = zipfile.ZipInfo(relative.as_posix())
                    entry.compress_type = zipfile.ZIP_DEFLATED
                    entry.external_attr = (stat.S_IFREG | mode) << 16
                    digest = hashlib.sha256()
                    size = 0
                    with os.fdopen(archive_descriptor, 'rb') as stream, bundle.open(entry, 'w', force_zip64=True) as output:
                        while chunk := stream.read(CHUNK):
                            output.write(chunk)
                            digest.update(chunk)
                            size += len(chunk)
                    inventory[entry.filename] = {'bytes': size, 'sha256': digest.hexdigest(), 'mode': mode, 'sqlite': is_sqlite}
                    if snapshot.exists():
                        snapshot.unlink()
        require(set(files) == set(enumerate_files()), 'State file set changed during backup; retry during a quieter period')
    checksum, size = digest_file(archive)
    manifest = {'formatVersion': 1, 'runId': run, 'completedAt': datetime.now(timezone.utc).isoformat(),
                'image': os.environ['HERMES_IMAGE'], 'consistency': 'online-per-database',
                'exclusions': 'native-pinned-policy-plus-runtime-markers; no external memory services or environment-only credentials',
                'archive': {'name': 'backup.zip', 'bytes': size, 'sha256': checksum}, 'files': inventory}
    verify_archive(manifest, archive)
    (WORK / 'manifest.json').write_text(json.dumps(manifest, separators=(',', ':')))
    (WORK / 'upload.tsv').write_text(f'{run}\t{size}\t{checksum}\n')
    print('Strict native snapshot verified; ready for upload')


def empty_target():
    require(ROOT.is_dir() and not ROOT.is_symlink(), 'Invalid restore target')
    entries = [entry for entry in ROOT.iterdir() if entry.name != 'lost+found']
    require(not entries, 'Restore target is not empty; no overwrite is permitted')
    lost = ROOT / 'lost+found'
    if lost.exists():
        require(lost.is_dir() and not lost.is_symlink() and not list(lost.iterdir()), 'Invalid lost+found directory')


def restore():
    completed = ROOT / '.helmforge-restored'
    if completed.is_file() and completed.read_text() == os.environ['RESTORE_MANIFEST_KEY']:
        print('This recovery was already completed; preserving current state')
        return
    empty_target()
    manifest_path = WORK / 'manifest.json'
    require(manifest_path.stat().st_size <= 20 * 1024 * 1024, 'Manifest exceeds maximum size')
    require((WORK / 'backup.zip').stat().st_size <= int(os.environ['MAX_ARCHIVE_BYTES']), 'Archive exceeds maximum size')
    manifest = json.loads(manifest_path.read_text())
    staging = WORK / 'restore'
    staging.mkdir(mode=0o700)
    verify_archive(manifest, WORK / 'backup.zip', staging)
    empty_target()
    marker = ROOT / '.helmforge-restore-incomplete'
    marker.write_text('Offline restore did not complete; do not start a gateway on this volume.\n')
    for source in staging.iterdir():
        destination = ROOT / source.name
        if source.is_dir():
            shutil.copytree(source, destination)
        else:
            shutil.copy2(source, destination)
    for name, metadata in manifest['files'].items():
        checksum, size = digest_file(ROOT / name)
        require(checksum == metadata['sha256'] and size == metadata['bytes'], 'Published restore verification failed')
    completed.write_text(os.environ['RESTORE_MANIFEST_KEY'])
    marker.unlink()
    print('Offline restore verified and completed')


def prepare_restore():
    completed = ROOT / '.helmforge-restored'
    require(not (ROOT / '.helmforge-restore-incomplete').exists(), 'Previous restore is incomplete')
    if completed.is_file() and not completed.is_symlink() and completed.read_text() == os.environ['RESTORE_MANIFEST_KEY']:
        (WORK / 'skip-restore').touch()
    else:
        empty_target()


if __name__ == '__main__':
    os.umask(0o077)
    try:
        {'backup': backup, 'restore': restore, 'prepare-restore': prepare_restore}[sys.argv[1]]()
    except Exception as error:
        detail = str(error) if type(error) is RuntimeError else type(error).__name__
        print(f'Archive operation failed: {detail}', file=sys.stderr)
        sys.exit(1)
