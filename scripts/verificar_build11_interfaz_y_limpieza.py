#!/usr/bin/env python3
from pathlib import Path
import zipfile,hashlib,re,json
root=Path(__file__).resolve().parents[1]
src=(root/'ThreeOneOSFive/ContentView.swift').read_text()
app=(root/'ThreeOneOSFive/App.swift').read_text()
assert 'NXGothicBackdrop()' in src and 'NXGothicBackdrop()' in app
assert 'Image("NexoraDarkCity")' in src
assert 'Limpiar temporales propios ahora' in src
assert 'activeReceiptCount' in src and 'Activaciones con recibo registrado' in src
assert 'NXOwnedTemporaryWorkspaces.cleanAll(keeping: protectedIDs)' in src
assert 'DevicePatchService.apply(project:' in src and 'DevicePatchService.restore(' in src
assert 'HOLOGRAMA PERSONAJE RAINBOW' in src
assert 'NEXORA SYSTEM' in app
assert (root/'ThreeOneOSFive/Assets.xcassets/NexoraDarkCity.imageset/NexoraDarkCity.jpg').stat().st_size > 250000
print('OK: UI roja con imagen real, activaciones presentes, limpieza protegida y Rainbow incluido.')
