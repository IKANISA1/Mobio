#!/usr/bin/env python3
"""Read-only validation of a Mobio privacy fulfilment evidence manifest.

This hashes local evidence and checks bindings/coverage. It does not execute
provider deletion, independently verify an operator's assertion, call a database,
change a case, invent retention periods, or establish legal compliance.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
from typing import Any

CATEGORIES = frozenset(('sessions','auth','profile_and_activity','financial_records',
                        'delivery_journals','storage','face_vectors','processors','backups','privacy_case_records'))
UUID = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
DIGEST = re.compile(r'^[0-9a-f]{64}$')
REFERENCE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_./:-]{0,127}$')
class EvidenceError(ValueError):
    """Public error codes deliberately omit evidence contents and subject IDs."""

def _object(pairs: list[tuple[str,Any]]) -> dict[str,Any]:
    result: dict[str,Any] = {}
    for key,value in pairs:
        if key in result: raise EvidenceError('DUPLICATE_JSON_KEY')
        result[key] = value
    return result

def safe_read(path: Path, limit: int) -> bytes:
    # POSIX descriptor-relative traversal rejects symlinks even when an ancestor
    # is renamed during the read. No FIFO open may block before the fstat check.
    import stat
    if os.name != 'posix' or not hasattr(os, 'O_NOFOLLOW'):
        raise EvidenceError('POSIX_NOFOLLOW_REQUIRED')
    parts=path.absolute().parts
    if any(part in ('.','..') for part in parts):raise EvidenceError('INVALID_EVIDENCE_PATH')
    directory=None
    try:
        directory=os.open('/',os.O_RDONLY|os.O_DIRECTORY)
        for component in parts[1:-1]:
            newer=os.open(component,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=directory)
            os.close(directory);directory=newer
        fd=os.open(parts[-1],os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=directory)
        with os.fdopen(fd,'rb') as stream:
            info=os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode):raise EvidenceError('REGULAR_FILE_REQUIRED')
            if info.st_size>limit:raise EvidenceError('EVIDENCE_TOO_LARGE')
            data=stream.read(limit+1)
        if len(data)>limit:raise EvidenceError('EVIDENCE_TOO_LARGE')
        return data
    except OSError as error:
        import errno
        code='SYMLINK_NOT_ALLOWED' if error.errno in (errno.ELOOP,errno.ENOTDIR) else 'EVIDENCE_FILE_UNAVAILABLE'
        raise EvidenceError(code) from error
    finally:
        if directory is not None:os.close(directory)

def parse_json(data: bytes) -> Any:
    try:
        value=json.loads(data.decode('utf-8'),object_pairs_hook=_object,
                         parse_constant=lambda _: (_ for _ in ()).throw(EvidenceError('NONFINITE_JSON')))
        pending=[(value,0)]
        while pending:
            item,depth=pending.pop()
            if depth>32:raise EvidenceError('JSON_NESTING_TOO_DEEP')
            if isinstance(item,dict):pending.extend((child,depth+1) for child in item.values())
            elif isinstance(item,list):pending.extend((child,depth+1) for child in item)
        return value
    except RecursionError as error:
        raise EvidenceError('JSON_NESTING_TOO_DEEP') from error
    except (UnicodeError,json.JSONDecodeError) as error:
        raise EvidenceError('INVALID_JSON') from error

def stamp(value: Any) -> datetime:
    if not isinstance(value,str) or len(value)>40 or not re.search(r'(Z|[+-]\d{2}:\d{2})$',value):
        raise EvidenceError('TIMEZONE_REQUIRED')
    try:
        date=datetime.fromisoformat(value.replace('Z','+00:00'))
        if date.tzinfo is None: raise ValueError()
        return date.astimezone(timezone.utc)
    except ValueError as error: raise EvidenceError('INVALID_TIMESTAMP') from error

def validate_manifest(path: Path, *, now: datetime|None=None) -> dict[str,Any]:
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None: raise EvidenceError('TIMEZONE_REQUIRED')
    raw=safe_read(path,65536); manifest=parse_json(raw)
    required={'schema_version','request_id','subject_id','notice_version','inventory_sha256',
              'plan_sha256','generated_at','receipts'}
    if not isinstance(manifest,dict) or set(manifest)!=required or type(manifest['schema_version']) is not int or manifest['schema_version']!=1:
        raise EvidenceError('INVALID_MANIFEST_SCHEMA')
    if any(not isinstance(manifest[k],str) or not UUID.fullmatch(manifest[k]) for k in ('request_id','subject_id')):
        raise EvidenceError('INVALID_IDENTITY')
    if any(not isinstance(manifest[k],str) or not DIGEST.fullmatch(manifest[k]) for k in ('inventory_sha256','plan_sha256')):
        raise EvidenceError('INVALID_PLAN_DIGEST')
    if not isinstance(manifest['notice_version'],str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,63}',manifest['notice_version']):
        raise EvidenceError('INVALID_NOTICE_VERSION')
    generated=stamp(manifest['generated_at'])
    if generated>now: raise EvidenceError('FUTURE_MANIFEST')
    receipts=manifest['receipts']
    if not isinstance(receipts,list) or len(receipts)!=len(CATEGORIES): raise EvidenceError('INCOMPLETE_CATEGORY_COVERAGE')
    seen:set[str]=set(); paths:set[str]=set(); retained=[]; verified=[]
    root=path.parent.absolute()
    for receipt in receipts:
        if not isinstance(receipt,dict) or set(receipt)!={'category','outcome','evidence_file','sha256','retention_until','basis_reference'}:
            raise EvidenceError('INVALID_RECEIPT_SCHEMA')
        category=receipt['category']; outcome=receipt['outcome']
        if not isinstance(category,str) or category not in CATEGORIES or category in seen: raise EvidenceError('DUPLICATE_OR_UNKNOWN_CATEGORY')
        seen.add(category)
        if outcome not in ('deleted','retained','not_applicable'): raise EvidenceError('INVALID_OUTCOME')
        if category in ('auth','sessions') and outcome!='deleted': raise EvidenceError('AUTH_ERASURE_REQUIRED')
        if category=='privacy_case_records' and outcome!='retained': raise EvidenceError('PRIVACY_CASE_RETENTION_REQUIRED')
        if outcome=='retained':
            expiry=stamp(receipt['retention_until'])
            basis=receipt['basis_reference']
            if expiry<=now or not isinstance(basis,str) or not REFERENCE.fullmatch(basis): raise EvidenceError('INVALID_RETENTION_EXCEPTION')
            retained.append(category)
        elif receipt['retention_until'] is not None or receipt['basis_reference'] is not None: raise EvidenceError('UNEXPECTED_RETENTION_EXCEPTION')
        name=receipt['evidence_file']
        if not isinstance(name,str) or len(name)>240 or '\\' in name or '\x00' in name:
            raise EvidenceError('INVALID_EVIDENCE_PATH')
        rel=PurePosixPath(name)
        if rel.is_absolute() or not rel.parts or any(part in ('.','..') for part in name.split('/')) or name in paths:
            raise EvidenceError('INVALID_EVIDENCE_PATH')
        paths.add(name)
        expected=receipt['sha256']
        if not isinstance(expected,str) or not DIGEST.fullmatch(expected): raise EvidenceError('INVALID_EVIDENCE_DIGEST')
        evidence=safe_read(root/Path(*rel.parts),1024*1024)
        if hashlib.sha256(evidence).hexdigest()!=expected: raise EvidenceError('EVIDENCE_DIGEST_MISMATCH')
        envelope=parse_json(evidence)
        if not isinstance(envelope,dict) or any(envelope.get(k)!=manifest[k] for k in ('request_id','subject_id')) or envelope.get('category')!=category or envelope.get('outcome')!=outcome:
            raise EvidenceError('EVIDENCE_BINDING_MISMATCH')
        if envelope.get('verification_mode') not in ('operator_attestation','provider_probe_record'):
            raise EvidenceError('VERIFICATION_MODE_REQUIRED')
        if stamp(envelope.get('observed_at'))>generated: raise EvidenceError('EVIDENCE_AFTER_MANIFEST')
        # Retention claims must agree in the evidence envelope and manifest.
        if envelope.get('retention_until')!=receipt['retention_until'] or envelope.get('basis_reference')!=receipt['basis_reference']:
            raise EvidenceError('RETENTION_BINDING_MISMATCH')
        verified.append({'category':category,'outcome':outcome,'sha256':expected})
    return {'schema_version':1,'status':'manifest_structure_and_files_verified',
            'manifest_sha256':hashlib.sha256(raw).hexdigest(),'category_count':len(seen),
            'retained_categories':sorted(retained),'receipts':sorted(verified,key=lambda x:x['category']),
            'provider_deletion_independently_verified':False,'database_case_changed':False}

def main(argv:list[str]|None=None)->int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest',type=Path);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(argv)
    try:
        result=validate_manifest(args.manifest)
        # Never overwrite existing evidence; create the output exclusively.
        flags=os.O_WRONLY|os.O_CREAT|os.O_EXCL|getattr(os,'O_NOFOLLOW',0)
        for parent in (args.output.absolute().parent,*args.output.absolute().parent.parents):
            if parent.is_symlink():raise EvidenceError('SYMLINK_NOT_ALLOWED')
        fd=os.open(args.output,flags,0o600)
        with os.fdopen(fd,'w') as stream:
            json.dump(result,stream,indent=2);stream.write('\n');stream.flush();os.fsync(stream.fileno())
        print('PASS: manifest structure, bindings and local file hashes only; no deletion executed.')
        return 0
    except (EvidenceError,OSError) as error:
        print(f'NOT VERIFIED: {error if isinstance(error,EvidenceError) else "OUTPUT_UNAVAILABLE"}',file=sys.stderr);return 2
if __name__=='__main__':raise SystemExit(main())
