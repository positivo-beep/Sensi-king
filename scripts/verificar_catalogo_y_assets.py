#!/usr/bin/env python3
"""Auditoría previa al build: impide anunciar como incluido un archivo ausente."""
from pathlib import Path
import hashlib,json,re,sys
root=Path(__file__).resolve().parents[1]
items=json.loads((root/'NEXORA_V14_MAPA_DE_OPCIONES.json').read_text(encoding='utf-8'))
swift=(root/'ThreeOneOSFive/ContentView.swift').read_text(encoding='utf-8')
base=root/'ThreeOneOSFive/Assets.xcassets'
errors=[]
included=[]
pending=[]
for item in items:
    label=item['opcion']
    state=item['estado']
    if state=='pendiente':
        pending.append(label)
        if item.get('recurso') or item.get('sha256'):
            errors.append(f'{label}: marcado pendiente con recurso/hash asignado')
        continue
    if state!='incluido':
        errors.append(f'{label}: estado no reconocido {state}')
        continue
    asset=item.get('recurso')
    expected=item.get('sha256')
    if not asset or not expected:
        errors.append(f'{label}: falta nombre de asset o SHA-256')
        continue
    asset_dir=base/(asset+'.dataset')
    contents=asset_dir/'Contents.json'
    if not contents.is_file():
        errors.append(f'{label}: no existe {contents.relative_to(root)}')
        continue
    try:
        desc=json.loads(contents.read_text(encoding='utf-8'))
        names=[o.get('filename') for o in desc.get('data',[]) if o.get('filename')]
    except (ValueError, OSError) as exc:
        errors.append(f'{label}: descriptor no legible: {exc}')
        continue
    if len(names)!=1:
        errors.append(f'{label}: descriptor de recurso ambiguo ({names})')
        continue
    data=asset_dir/names[0]
    if not data.is_file():
        errors.append(f'{label}: falta archivo binario {names[0]}')
        continue
    sha=hashlib.sha256(data.read_bytes()).hexdigest()
    if sha != expected:
        errors.append(f'{label}: SHA-256 incorrecto para {asset}: {sha}')
    if 'tamano_bytes' in item and data.stat().st_size != item['tamano_bytes']:
        errors.append(f'{label}: tamaño declarado diferente al real')
    if not re.search(r'dataAsset:\s*"'+re.escape(asset)+r'"',swift):
        errors.append(f'{label}: recurso {asset} no está registrado en ContentView.swift')
    if not re.search(r'title:\s*"'+re.escape(label)+r'"',swift):
        errors.append(f'{label}: botón no está en ContentView.swift')
    included.append(label)
if len(included)!=len(set(included)) or len(pending)!=len(set(pending)):
    errors.append('Opciones duplicadas en catálogo')
for label in included:
    if label in pending:
        errors.append(f'{label}: catalogada como incluida y pendiente al mismo tiempo')
print(f'Recursos comprobados: {len(included)} | Sin archivos reales: {len(pending)}')
if pending:
    print('Opciones no activables por falta de datos: '+', '.join(pending))
if errors:
    for error in errors: print('ERROR:',error)
    sys.exit(1)
print('OK: todos los recursos declarados como incluidos están presentes y coinciden con sus hashes.')
