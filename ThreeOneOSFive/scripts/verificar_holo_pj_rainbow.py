#!/usr/bin/env python3
"""Comprobar recurso Rainbow antes de Xcode. No prueba uso en Free Fire/iPhone."""
from pathlib import Path
import re, json, hashlib
base=Path(__file__).resolve().parents[1]
app=base/'ThreeOneOSFive'
ui=(app/'ContentView.swift').read_text()
name='HOLOGRAMA PERSONAJE RAINBOW'
file='optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D'
asset='NXModHoloPjRainbow'
expected='71cdc24d159dec937ec14bb373dc8d2fa59cab38f79274981e62a75b68e2337c'
options=re.findall(r'NXBundledOption\(id: UUID\(uuidString: "([^"]+)"\)!, title: "([^"]+)", category: "([^"]+)", dataAsset: "([^"]*)", targetPath: "([^"]+)", filename: "([^"]+)"\)',ui)
row=[v for v in options if v[1]==name]
assert len(row)==1 and row[0][2]=='HOLO PJ' and row[0][3]==asset
assert row[0][4].endswith(file) and row[0][5]==file
assert '"HOLO PJ": ["HOLOGRAMA PERSONAJE VERDE"]' in ui
assert 'HOLOGRAMA PERSONAJE ROJO' not in ui
rainbow=(app/'Assets.xcassets'/f'{asset}.dataset')
meta=json.loads((rainbow/'Contents.json').read_text())
assert meta['data'][0]['filename']==file
blob=(rainbow/file).read_bytes()
assert len(blob)==381140 and blob.startswith(b'UnityFS\x00')
assert hashlib.sha256(blob).hexdigest()==expected
catalog=json.loads((base/'NEXORA_V14_MAPA_DE_OPCIONES.json').read_text())
entry=[x for x in catalog if x['opcion']==name]
assert len(entry)==1 and entry[0]['estado']=='incluido' and entry[0]['sha256']==expected
assert entry[0]['destino_relativo']==row[0][4]
for companion in ('HOLOGRAMA PERSONAJE AZUL','HOLOGRAMA PERSONAJE AMARILLO'):
    assert next(v for v in options if v[1]==companion)[4]==row[0][4]
for copy in (base/'BundledMods',base.parent/'BundledMods'):
    assert hashlib.sha256((copy/'HOLO PERSONAJE'/'Holograma personaje Rainbow'/file).read_bytes()).hexdigest()==expected
print('RAINBOW OK: recurso real, hash SHA-256, opción activa, exclusión de destino, catálogo sincronizado.')
print('PENDIENTE: compilación Xcode e instalación / permisos / compatibilidad en iPhone.')
