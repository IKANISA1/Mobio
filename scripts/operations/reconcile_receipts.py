#!/usr/bin/env python3
"""Read-only reconciliation of approved, normalized operator/receipt/credit exports.

Never calls a provider, changes a ledger, activates an invoice, or treats a match
as independent proof that the supplied operator export is authentic. Run in an
access-controlled workspace: transaction/invoice references are sensitive.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any

FIELDS = {
    'operator': ('operator','merchant','transaction_ref','amount_minor','currency','occurred_at'),
    'receipts': ('receipt_id','operator','merchant','transaction_ref','amount_minor','currency','state','invoice_id'),
    'credits': ('credit_id','invoice_id','operator','merchant','transaction_ref','amount_minor','currency'),
}
STATES = {'admitted','processing','review','rejected','credited'}
MAX_BYTES = 32 * 1024 * 1024
MAX_ROWS = 100_000

class InputError(ValueError):
    """Invalid normalized input. Error messages never echo its cell contents."""

def instant(value: str) -> datetime:
    try:
        result = datetime.fromisoformat(value.replace('Z','+00:00'))
    except (ValueError, TypeError):
        raise InputError('Invalid timestamp') from None
    if result.tzinfo is None: raise InputError('Timestamp requires an explicit UTC offset')
    return result.astimezone(timezone.utc)

def normalize(row: dict[str, str], kind: str, number: int) -> dict[str, Any]:
    if kind not in FIELDS or set(row) != set(FIELDS[kind]):
        raise InputError(f'{kind} row {number}: header/column mismatch')
    if any(not isinstance(v,str) or len(v)>256 or any(ord(c)<32 for c in v) for v in row.values()):
        raise InputError(f'{kind} row {number}: invalid field encoding/length')
    r = {k:v.strip() for k,v in row.items()}
    optional = {'invoice_id'} if kind=='receipts' else set()
    if any(not v and k not in optional for k,v in r.items()):
        raise InputError(f'{kind} row {number}: missing required field')
    if not re.fullmatch(r'[1-9][0-9]{0,15}',r['amount_minor']) or int(r['amount_minor'])>9007199254740991:
        raise InputError(f'{kind} row {number}: invalid integer amount')
    if not re.fullmatch(r'[A-Z]{3}',r['currency']): raise InputError(f'{kind} row {number}: invalid currency')
    r['amount_minor']=int(r['amount_minor'])
    if kind=='operator': instant(r['occurred_at'])
    if kind=='receipts' and r['state'] not in STATES: raise InputError(f'{kind} row {number}: unmapped state')
    return r

def load(path: Path, kind: str) -> list[dict[str, Any]]:
    if path.is_symlink() or not path.is_file() or path.stat().st_size>MAX_BYTES:
        raise InputError(f'{kind}: missing, linked, or oversized input')
    try:
        with path.open(encoding='utf-8-sig',newline='') as handle:
            reader=csv.DictReader(handle)
            if reader.fieldnames is None or len(reader.fieldnames)!=len(set(reader.fieldnames)) or set(reader.fieldnames)!=set(FIELDS[kind]):
                raise InputError(f'{kind}: exact normalized headers required')
            out=[]
            for i,row in enumerate(reader,2):
                if len(out)>=MAX_ROWS: raise InputError(f'{kind}: row limit exceeded')
                out.append(normalize(row,kind,i))
            return out
    except (csv.Error,UnicodeError): raise InputError(f'{kind}: malformed CSV') from None

def reconcile(operator: list[dict], receipts: list[dict], credits: list[dict], *, as_of: datetime) -> dict:
    """Every key is operator+merchant+exact reference; never amount/time matching."""
    if as_of.tzinfo is None: raise InputError('Cutoff requires timezone')
    groups={kind:defaultdict(list) for kind in FIELDS}
    issues=[];matches=[];pending=[]
    for kind,rows in [('operator',operator),('receipts',receipts),('credits',credits)]:
        seen_ids=set()
        for row in rows:
            if kind=='operator' and instant(row['occurred_at'])>as_of: raise InputError('Operator row is after reconciliation cutoff')
            if kind!='operator':
                field='receipt_id' if kind=='receipts' else 'credit_id'
                if row[field] in seen_ids: raise InputError(f'{kind}: duplicate record identity')
                seen_ids.add(row[field])
            groups[kind][(row['operator'],row['merchant'],row['transaction_ref'])].append(row)
    invoices=defaultdict(list)
    for c in credits: invoices[c['invoice_id']].append(c['credit_id'])
    for invoice,ids in sorted(invoices.items()):
        if len(ids)>1: issues.append({'code':'DUPLICATE_INVOICE_CREDIT','invoice_id':invoice,'credit_ids':ids})
    keys=set().union(*(set(g) for g in groups.values()))
    for key in sorted(keys):
        o=groups['operator'][key];r=groups['receipts'][key];c=groups['credits'][key]
        item={'operator':key[0],'merchant':key[1],'transaction_ref':key[2]}
        codes=[]
        if len(o)>1: codes.append('DUPLICATE_OPERATOR_REFERENCE')
        if len(r)>1: codes.append('MULTIPLE_RECEIPT_RECORDS')
        if len(c)>1: codes.append('MULTIPLE_CREDIT_RECORDS')
        if not o: codes.append('NO_OPERATOR_EVIDENCE')
        if not r: codes.append('NO_RECEIPT_RECORD')
        if len(o)==len(r)==len(c)==1:
            evidence=[o[0],r[0],c[0]]
            if len({x['amount_minor'] for x in evidence})!=1: codes.append('AMOUNT_MISMATCH')
            if len({x['currency'] for x in evidence})!=1: codes.append('CURRENCY_MISMATCH')
            if not r[0]['invoice_id'] or r[0]['invoice_id']!=c[0]['invoice_id']: codes.append('INVOICE_BINDING_MISMATCH')
            if r[0]['state']!='credited': codes.append('CREDIT_WITH_INCONSISTENT_RECEIPT_STATE')
            if len(invoices[c[0]['invoice_id']])>1: codes.append('INVOICE_CREDIT_NOT_UNIQUE')
            if not codes: matches.append({**item,'invoice_id':c[0]['invoice_id'],'credit_id':c[0]['credit_id']})
        elif len(o)==len(r)==1 and not c:
            if o[0]['amount_minor']!=r[0]['amount_minor']: codes.append('AMOUNT_MISMATCH')
            if o[0]['currency']!=r[0]['currency']: codes.append('CURRENCY_MISMATCH')
            if r[0]['state'] in {'admitted','processing'} and not codes:
                pending.append({**item,'state':r[0]['state'],'receipt_id':r[0]['receipt_id']})
            else: codes.append('NO_CREDIT_REQUIRES_REVIEW')
        elif not c: codes.append('NO_CREDIT_RECORD')
        for code in codes: issues.append({**item,'code':code})
    return {'schema_version':1,'as_of':as_of.astimezone(timezone.utc).isoformat(),
            'mode':'READ_ONLY_NORMALIZED_EXPORT_COMPARISON','authenticity_verified':False,
            'counts':{'operator_rows':len(operator),'receipt_rows':len(receipts),'credit_rows':len(credits),
                      'matched':len(matches),'pending':len(pending),'exceptions':len(issues)},
            'matched':matches,'pending':pending,'exceptions':issues,
            'release_decision':'NOT_DETERMINED','automatic_credit_performed':False}

def main(argv: list[str]|None=None) -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    for kind in FIELDS: parser.add_argument('--'+kind,type=Path,required=True)
    parser.add_argument('--as-of',required=True)
    parser.add_argument('--output',type=Path,required=True,help='New directory; never overwrites a prior report.')
    args=parser.parse_args(argv)
    try:
        output=args.output.expanduser().absolute()
        if output.exists() or any(p.is_symlink() for p in [output,*output.parents]): raise InputError('Output must be a new non-symlink directory')
        inputs={kind:getattr(args,kind) for kind in FIELDS}
        data={kind:load(path,kind) for kind,path in inputs.items()}
        report=reconcile(data['operator'],data['receipts'],data['credits'],as_of=instant(args.as_of))
        report['input_sha256']={kind:hashlib.sha256(path.read_bytes()).hexdigest() for kind,path in inputs.items()}
        output.mkdir(parents=True,mode=0o700)
        target=output/'reconciliation.json'
        with target.open('x',encoding='utf-8') as handle: json.dump(report,handle,indent=2,ensure_ascii=True);handle.write('\n')
        target.chmod(0o600)
        print(json.dumps({'status':'REVIEW_REQUIRED' if report['exceptions'] else 'COMPARISON_COMPLETE','counts':report['counts']}))
        return 1 if report['exceptions'] else 0
    except (InputError,OSError) as error:
        # OSError can include a filename; no raw input/cell/provider value is logged.
        print('RECONCILIATION_INPUT_REJECTED: '+(str(error) if isinstance(error,InputError) else 'filesystem unavailable'),file=sys.stderr)
        return 2
if __name__=='__main__': raise SystemExit(main())
