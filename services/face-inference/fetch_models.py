"""Fetch only the pinned, checksum-verified artifacts. Never run at service startup."""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parent

def fetch():
    target = ROOT / 'models'
    target.mkdir(exist_ok=True)
    for item in json.loads((ROOT / 'model-manifest.json').read_text())['models']:
        path = target / item['file']
        if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256']:
            continue
        with urllib.request.urlopen(item['url'], timeout=60) as response:
            data = response.read(45_000_001)
        if len(data)>45_000_000 or hashlib.sha256(data).hexdigest() != item['sha256']:
            raise RuntimeError('Model checksum mismatch')
        temporary = path.with_suffix('.download')
        temporary.write_bytes(data)
        temporary.replace(path)
        print('Verified',item['role'],item['sha256'])

if __name__ == '__main__': fetch()
