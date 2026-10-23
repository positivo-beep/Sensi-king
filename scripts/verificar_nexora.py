from pathlib import Path
import json, plistlib, xml.etree.ElementTree as ET
root = Path(__file__).resolve().parent.parent
proj = (root / 'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
# Los archivos de prueba en subcarpetas scripts/ o tests/ NO pertenecen
# al target de la app de iOS. No deben exigirse en PBXSourcesBuildPhase.
source_root = root / 'ThreeOneOSFive'
excluded_dirs = {'scripts', 'tests', 'Tests'}
files = [
    f for f in source_root.rglob('*.swift')
    if not any(part in excluded_dirs for part in f.relative_to(source_root).parts[:-1])
]
assert files, 'No se encontraron fuentes Swift'
for f in files:
    assert f'/* {f.name} in Sources */' in proj, f'No esta agregado a Sources: {f}'
for data in (root / 'ThreeOneOSFive/Assets.xcassets').rglob('Contents.json'):
    obj = json.loads(data.read_text())
    for entry in obj.get('images', []) + obj.get('data', []):
        if entry.get('filename'):
            assert (data.parent / entry['filename']).is_file(), f'Falta recurso: {entry["filename"]}'
info = plistlib.loads((root / 'ThreeOneOSFive/Info.plist').read_bytes())
assert info['CFBundleDisplayName'] == 'NEXORA SYSTEM 2026'
app = (root/'ThreeOneOSFive/App.swift').read_text()
assert 'hypersex-licencias-propias.nexora-system26.workers.dev' in app
assert '/v1/validate' in app and '/v1/activate' in app
panel = (root/'ThreeOneOSFive/ContentView.swift').read_text()
assert 'DevicePatchService.apply(' in panel and 'DevicePatchService.restore(' in panel
ET.parse(root/'ThreeOneOSFive.xcodeproj/xcshareddata/xcschemes/NEXORA_SYSTEM_2026.xcscheme')
print(f'PREVERIFICACION OK: {len(files)} fuentes Swift, assets, esquema Xcode, licencia, motor original.')
