#!/usr/bin/env python3
"""Check/apply the reviewed Increment05 delta to a matching isolated checkout.

Checksums detect drift, not authenticity. Review the package first. Default is
check-only. All preconditions are checked before writing; replacement is atomic
per file, not a cross-file filesystem transaction. Use a clean review branch.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path,PurePosixPath
import sys
import stat
import tempfile


def sha(data: bytes) -> str: return hashlib.sha256(data).hexdigest()


def safe_path(root: Path, relative: str) -> Path:
    value=PurePosixPath(relative)
    if not relative or value.is_absolute() or '\\' in relative or any(x in ('','..','.') for x in relative.split('/')):
        raise ValueError('Invalid manifest path')
    if root.is_symlink():raise ValueError("Symlinked payload root refused")
    current=root
    for part in value.parts:
        current=current/part
        if current.is_symlink():raise ValueError(f'Symlink refused: {relative}')
    return current


def plan(repo: Path,bundle: Path) -> list[tuple[Path,bytes,int,str]]:
    for root in (repo, bundle):
        if any(part.is_symlink() for part in (root, *root.parents)):
            raise ValueError('Symlinked checkout or bundle root refused')
    repo=repo.resolve();bundle=bundle.resolve()
    if (bundle/'DELTA_MANIFEST.json').is_symlink():raise ValueError('Symlinked manifest refused')
    if not repo.is_dir() or not (repo/'.git').exists(): raise ValueError('Use an existing isolated Git checkout')
    manifest=json.loads((bundle/'DELTA_MANIFEST.json').read_text())
    if manifest.get('schema_version')!=1 or not isinstance(manifest.get('files'),list) or not manifest['files']:
        raise ValueError('Invalid delta manifest')
    seen=set();changes=[]
    for entry in manifest['files']:
        relative=entry['path']
        if relative in seen:raise ValueError('Duplicate manifest path')
        seen.add(relative)
        if relative=='.git' or relative.startswith('.git/'):raise ValueError('Git metadata changes refused')
        source=safe_path(bundle/'delta-files',relative);target=safe_path(repo,relative)
        if not source.is_file() or source.stat().st_size>10_000_000: raise ValueError(f'Missing or oversized payload: {relative}')
        data=source.read_bytes()
        if sha(data)!=entry['after_sha256']:raise ValueError(f'Payload checksum mismatch: {relative}')
        if target.exists() and not target.is_file():raise ValueError(f'Target is not a file: {relative}')
        actual=sha(target.read_bytes()) if target.exists() else None
        if actual not in (entry['before_sha256'],entry['after_sha256']):raise ValueError(f'Baseline differs; reconcile before applying: {relative}')
        mode=entry.get('after_mode',420)
        if mode not in (420,493):raise ValueError('Unsupported file mode')
        if actual!=entry['after_sha256'] or stat.S_IMODE(target.stat().st_mode)!=mode:changes.append((target,data,mode,relative))
    return changes


def apply(repo: Path,bundle: Path) -> int:
    changes=plan(repo,bundle);staged=[]
    try:
        for target,data,mode,_ in changes:
            target.parent.mkdir(parents=True,exist_ok=True)
            fd,temp=tempfile.mkstemp(prefix='.mobio-increment05-',dir=target.parent)
            staged.append((Path(temp),target))
            with os.fdopen(fd,'wb') as output: output.write(data);output.flush();os.fsync(output.fileno())
            os.chmod(temp,mode)
        # Recheck after staging; do not overwrite concurrent edits detected here.
        if [x[3] for x in plan(repo,bundle)]!=[x[3] for x in changes]:raise ValueError('Checkout changed during staging')
        for temp,target in staged:os.replace(temp,target)
        if plan(repo,bundle):raise RuntimeError('Post-apply verification failed')
        return len(changes)
    finally:
        for temp,_ in staged:
            if temp.exists():temp.unlink()


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--repo',required=True,type=Path)
    parser.add_argument('--bundle',required=True,type=Path);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    changes=plan(args.repo,args.bundle)
    if args.apply:count=apply(args.repo,args.bundle)
    else:count=len(changes)
    print(json.dumps({'mode':'applied' if args.apply else 'check_only','files_to_change_or_changed':count,'database_or_deployment_actions':False}))
    return 0

if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError,KeyError,TypeError,RuntimeError) as exc: print(str(exc),file=sys.stderr);sys.exit(1)
