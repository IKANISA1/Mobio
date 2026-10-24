#!/usr/bin/env python3
"""Verify and decrypt a private retirement backup. Does not extract files.

python3 RESTORE_PRIVATE.py private-backup.json downloaded-parts/ restored.tar.gz
Download the exact part names listed in the JSON from the referenced private
GitHub draft release. Supply the recovery key from the completion chat.
"""
import getpass,hashlib,hmac,json,os,subprocess,sys,threading
from pathlib import Path

meta=json.loads(Path(sys.argv[1]).read_text());directory=Path(sys.argv[2]);out=Path(sys.argv[3])
if out.exists():raise SystemExit('Output exists; choose a new path.')
password=getpass.getpass('Recovery key: ').encode()
authkey=hashlib.sha256(b'codex-local-retirement-hmac-v1\0'+password).digest()
auth=hmac.new(authkey,digestmod='sha256');total=hashlib.sha256();parts=[]
for rec in meta['parts']:
 p=directory/rec['name'];h=hashlib.sha256();size=0
 with p.open('rb') as f:
  while b:=f.read(1024*1024):h.update(b);total.update(b);auth.update(b);size+=len(b)
 if h.hexdigest()!=rec['sha256'] or size!=rec['bytes']:raise SystemExit('Part integrity failure: '+p.name)
 parts.append(p)
if total.hexdigest()!=meta['cipher_sha256'] or not hmac.compare_digest(auth.hexdigest(),meta['cipher_hmac_sha256']):
 raise SystemExit('Authentication failed. Check the recovery key and files. Nothing decrypted.')
readfd,writefd=os.pipe()
os.write(writefd,password+b'\n');os.close(writefd)
help_text=subprocess.run(['openssl','enc','-help'],capture_output=True,text=True)
salt_options=['-saltlen',str(meta.get('salt_bytes',8))] if '-saltlen' in help_text.stdout+help_text.stderr else []
with os.fdopen(os.open(out,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'wb') as output:
 proc=subprocess.Popen(['openssl','enc','-d','-aes-256-cbc','-pbkdf2','-iter','600000','-md','sha256',*salt_options,'-pass','fd:'+str(readfd)],pass_fds=(readfd,),stdin=subprocess.PIPE,stdout=output)
 os.close(readfd)
 def feed():
  try:
   for p in parts:
    with p.open('rb') as f:
     while b:=f.read(1024*1024):proc.stdin.write(b)
  finally:proc.stdin.close()
 thread=threading.Thread(target=feed);thread.start();code=proc.wait();thread.join()
if code:out.unlink();raise SystemExit('Decryption failed.')
h=hashlib.sha256()
with out.open('rb') as f:
 while b:=f.read(1024*1024):h.update(b)
if h.hexdigest()!=meta['plaintext_gzip_sha256']:out.unlink();raise SystemExit('Decrypted archive integrity failure.')
print('Authenticated and decrypted:',out)
