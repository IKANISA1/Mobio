#!/usr/bin/env python3
"""Prepare reviewed SQL bodies using the installed Supabase CLI. Never applies SQL.

Default: print the plan. --check: require exact ordered generated migrations.
--write: ask `supabase migration new` to create names, then fill those empty files.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

BUNDLE = Path('supabase/hardening/2026-09-28')
MIGRATION = re.compile(r'([0-9]{14})_([a-z][a-z0-9_]+)\.sql\Z')


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def regular_path(root: Path, relative: Path, directory: bool = False) -> Path:
    if relative.is_absolute() or any(p in ('..', '.') for p in relative.parts):
        raise ValueError('Invalid bundle path')
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f'Symlink not allowed: {relative}')
    if (not current.is_dir()) if directory else (not current.is_file()):
        raise ValueError(f'Missing required path: {relative}')
    return current


def plan(root: Path) -> list[dict]:
    manifest = regular_path(root, BUNDLE / 'manifest.json')
    spec = json.loads(manifest.read_text(encoding='utf-8'))
    if spec.get('schema_version') != 1 or not isinstance(spec.get('bodies'), list) or not spec['bodies']:
        raise ValueError('Invalid hardening manifest')
    migrations = regular_path(root, Path('supabase/migrations'), directory=True)
    names, rows = set(), []
    paths = sorted(migrations.glob('*.sql'))
    timestamps = [MIGRATION.fullmatch(p.name).group(1) for p in paths if MIGRATION.fullmatch(p.name)]
    if len(set(timestamps)) != len(timestamps):
        raise ValueError('Duplicate existing migration timestamps: reconcile before preparation')
    last_installed = ''
    encountered_missing = False
    for entry in spec['bodies']:
        name = entry.get('migration_name', '')
        filename = entry.get('file', '')
        checksum = entry.get('sha256', '')
        if not re.fullmatch(r'mobio_hardening_[a-z0-9_]+', name) or name in names:
            raise ValueError('Invalid or duplicate migration name')
        if not re.fullmatch(r'[0-9]{2}_[a-z0-9_]+\.sql', filename) or not re.fullmatch('[0-9a-f]{64}', checksum):
            raise ValueError('Invalid body filename or checksum')
        names.add(name)
        body = regular_path(root, BUNDLE / filename)
        if digest(body) != checksum:
            raise ValueError(f'Body checksum differs: {filename}; review and regenerate manifest')
        matches = [p for p in paths if p.name.endswith('_' + name + '.sql')]
        if len(matches) > 1:
            raise ValueError(f'Multiple migrations for body {name}')
        installed = matches[0] if matches else None
        if installed:
            regular_path(root, installed.relative_to(root))
            match = MIGRATION.fullmatch(installed.name)
            if not match or digest(installed) != checksum:
                raise ValueError(f'Generated migration differs: {installed.name}; do not overwrite applied history')
            if encountered_missing or match.group(1) <= last_installed:
                raise ValueError('Hardening migration order is incomplete or invalid')
            last_installed = match.group(1)
        else:
            encountered_missing = True
        rows.append({'file': filename, 'migration_name': name, 'sha256': checksum,
                     'installed': str(installed.relative_to(root)) if installed else None})
    return rows


def generate(root: Path, cli: str, rows: list[dict]) -> None:
    """CLI only creates migration files. No database or project credentials needed."""
    binary = shutil.which(cli)
    if not binary:
        raise RuntimeError('Supabase CLI unavailable: no migrations generated or applied')
    subprocess.run([binary, 'migration', 'new', '--help'], cwd=root, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=30)
    migration_dir = root / 'supabase/migrations'
    for row in rows:
        if row['installed']:
            continue
        before = set(migration_dir.glob('*.sql'))
        previous = max((MIGRATION.fullmatch(p.name).group(1) for p in before if MIGRATION.fullmatch(p.name)), default='')
        subprocess.run([binary, 'migration', 'new', row['migration_name']], cwd=root,
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
        created = set(migration_dir.glob('*.sql')) - before
        if len(created) != 1:
            raise RuntimeError('CLI did not create exactly one migration; inspect before retry')
        target = created.pop()
        match = MIGRATION.fullmatch(target.name)
        if not match or match.group(2) != row['migration_name'] or match.group(1) <= previous:
            raise RuntimeError('CLI migration timestamp/name out of order; inspect generated file before retry')
        if target.is_symlink() or target.stat().st_size != 0:
            raise RuntimeError('CLI-generated migration is not an empty regular file; it was not overwritten')
        body = regular_path(root, BUNDLE / row['file']).read_bytes()
        if hashlib.sha256(body).hexdigest() != row['sha256']:
            raise RuntimeError('Body changed during preparation')
        fd, temp_name = tempfile.mkstemp(prefix='.mobio-migration-', dir=migration_dir)
        try:
            with os.fdopen(fd, 'wb') as output:
                output.write(body)
                output.flush()
                os.fsync(output.fileno())
            os.chmod(temp_name, 0o644)
            os.replace(temp_name, target)
        finally:
            if os.path.exists(temp_name):
                os.unlink(temp_name)
        print(f'Prepared {target.relative_to(root)}; NOT applied')
        # Supabase migration names use seconds; avoid same-version creation in a batch.
        time.sleep(1.1)
    checked = plan(root)
    if any(not row['installed'] for row in checked):
        raise RuntimeError('Preparation incomplete')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--write', action='store_true')
    parser.add_argument('--supabase', default='supabase', help='Installed CLI executable, used only with --write')
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        rows = plan(root)
        if args.write:
            # Atomic same-checkout coordination. An abandoned lock requires explicit inspection.
            lock = root / '.mobio-hardening-prepare.lock'
            fd = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            try:
                with os.fdopen(fd, 'w') as handle:
                    handle.write(str(os.getpid()) + '\n')
                generate(root, args.supabase, plan(root))
            finally:
                lock.unlink(missing_ok=True)
            return 0
        print(json.dumps({'database_applied': False, 'migrations': rows}, indent=2))
        if args.check and any(not row['installed'] for row in rows):
            print('INCOMPLETE: reviewed bodies must be generated into ordered migrations using --write; no SQL applied', file=sys.stderr)
            return 2
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f'NO-GO: migration preparation: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
