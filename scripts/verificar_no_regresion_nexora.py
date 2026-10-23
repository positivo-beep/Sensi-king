#!/usr/bin/env python3
"""Guarda el motor previo sin tocar kernel/sandbox/rutas de activación."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
base=json.loads((root/'NEXORA_BASE_BUILD8_SHA256.json').read_text())
changed=json.loads((root/'NEXORA_MEJORAS_SEGURAS_SHA256.json').read_text())
ui=json.loads((root/'NEXORA_BUILD12_PRESENTACION_SHA256.json').read_text())
update13=json.loads((root/'NEXORA_BUILD13_UI_SHA256.json').read_text())
update14=json.loads((root/'NEXORA_BUILD14_UI_SHA256.json').read_text())
update15=json.loads((root/'NEXORA_BUILD15_CAMBIOS_SHA256.json').read_text())
update16=json.loads((root/'NEXORA_BUILD16_CAMBIOS_SHA256.json').read_text())
alok=json.loads((root/'NEXORA_ALOK_CAMBIOS_SHA256.json').read_text())
manifest=json.loads((root/'NEXORA_INVENTARIO_SHA256.json').read_text())
assert set(ui)=={'ThreeOneOSFive/App.swift','ThreeOneOSFive/ContentView.swift'}
assert set(changed)=={
    'ThreeOneOSFive/helpers/LimitedCleanerService.swift',
    'ThreeOneOSFive/helpers/NXOwnedTemporaryWorkspaces.swift'
}
for path, expected in update15.items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==manifest.get(path,alok.get(path,update16.get(path, expected))), path
for path, expected in base.items():
    if path in changed or path in ui or path in update15 or path in update16:continue
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==expected, path
for path,expected in changed.items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==expected,path
for path, expected in ui.items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==manifest.get(path,alok.get(path,update16.get(path,update14.get(path,update13.get(path,expected))))), path
for path, expected in update13.items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==manifest.get(path,alok.get(path,update16.get(path,update14.get(path,expected)))),path
print('OK: motor protegido conserva huellas originales; cambios visuales y de limpieza autorizados.')
