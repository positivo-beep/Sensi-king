#!/usr/bin/env python3
"""Control de integridad del proyecto elegido. No verifica permisos ni resultados en iPhone."""
from pathlib import Path
import hashlib, json, struct, plistlib, re
root=Path(__file__).resolve().parents[2]
app=root/'ThreeOneOSFive/ThreeOneOSFive'
project=root/'ThreeOneOSFive/ThreeOneOSFive.xcodeproj/project.pbxproj'
s=project.read_text(encoding='utf8')
start=s.index('/* Begin PBXGroup section */'); end=s.index('/* End PBXGroup section */',start)
assert '3105N401 /* NXAntennaOnlyUnityFS.swift in Sources */,' not in s[start:end], 'ID de build colocado en PBXGroup'
start=s.index('/* Begin PBXSourcesBuildPhase section */'); end=s.index('/* End PBXSourcesBuildPhase section */',start)
assert s[start:end].count('3105N401,')==1, 'Antena SOLA no registrada en compilación'
assert 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' in s, 'Icono iOS no registrado'
manifest=json.loads((root/'NEXORA_VERSION_VERIFICADA.json').read_text(encoding='utf8'))
for name, expected in manifest['sha256'].items():
    p=root/name
    assert p.is_file(), f'Archivo obligatorio ausente: {name}'
    digest=hashlib.sha256(p.read_bytes()).hexdigest()
    assert digest==expected, f'Archivo cambiado o incompleto: {name}'
icons=app/'Assets.xcassets/AppIcon.appiconset'
info=json.loads((icons/'Contents.json').read_text())
assert any(x.get('filename')=='AppIcon-1024.png' for x in info['images'])
icon=(icons/'AppIcon-1024.png').read_bytes()
assert icon[:8]==b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>II',icon[16:24])==(1024,1024), 'Icono de tamaño incorrecto'
assets=app/'Assets.xcassets'
count=0
for p in assets.glob('NXMod*.dataset'):
    data=json.loads((p/'Contents.json').read_text())['data']
    assert len(data)==1 and data[0].get('filename'), f'Dataset no válido: {p.name}'
    assert (p/data[0]['filename']).stat().st_size>0
    count+=1
assert count>=12, f'Se esperaban al menos 12 recursos, hay {count}'
mods=[p for p in (root/'BundledMods').rglob('*') if p.is_file() and p.name!='.gitkeep']
assert len(mods)>=10, f'Carpeta BundledMods incompleta ({len(mods)} archivos)'
assert len(list(app.rglob('*.swift')))>=50, 'Fuentes Swift incompletas'
app_swift=(app/'App.swift').read_text()
panel=(app/'ContentView.swift').read_text()
assert 'NexoraKeyScreen' in app_swift and 'NXGothicBackdrop()' in app_swift
assert 'NXGothicBackdrop()' in panel and 'Image("NexoraMark")' in panel
assert 'NXOwnedTemporaryWorkspaces.cleanAll' in panel
plist=plistlib.load(open(app/'Info.plist','rb'))
assert plist['CFBundleDisplayName']=='NEXORA SYSTEM 2026'
print(f'ENTREGA COMPLETA OK: {len(mods)} recursos de origen, {count} datasets, logo 1024px, SwiftUI, keys y limpieza.')
