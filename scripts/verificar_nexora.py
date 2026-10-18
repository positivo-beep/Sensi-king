from pathlib import Path
import json, plistlib, xml.etree.ElementTree as ET
root = Path(__file__).resolve().parent.parent
proj = (root / 'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
# Solo los archivos Swift de la app requieren estar en Sources.
# Las pruebas de linea de comandos dentro de ThreeOneOSFive/scripts
# se ejecutan por separado y no deben añadirse al proyecto iOS.
files = [f for f in root.glob('ThreeOneOSFive/**/*.swift')
         if 'scripts' not in f.relative_to(root / 'ThreeOneOSFive').parts]
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
