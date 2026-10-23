#!/usr/bin/env python3
"""Verifica presencia e integridad de todos los archivos inventariados del proyecto."""
from pathlib import Path
import json, hashlib, sys
root = Path(__file__).resolve().parents[1]
entries = json.loads((root / 'NEXORA_INVENTARIO_SHA256.json').read_text(encoding='utf-8'))
fail=[]
for name, expected in entries.items():
    p=(root/name)
    if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=expected:
        fail.append(name)
if fail:
    print('ERROR: Archivos faltantes o alterados:')
    print('\n'.join(fail))
    sys.exit(1)
print(f'OK: {len(entries)} archivos inventariados íntegros.')
