#!/usr/bin/env python3
"""Control de fuente y nombres de assets; no evalúa acceso a apps externas."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
app=(root/'ThreeOneOSFive/App.swift').read_text()
view=(root/'ThreeOneOSFive/ContentView.swift').read_text()
project=(root/'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
assert 'Text("B16 · ROJO")' in view
assert 'NEXORA ROJO · BUILD 12 · ACCESO AUTORIZADO' in app
assert 'NexoraPalette.purple' not in app and 'NXColors.purple' not in view
assert 'NexoraDarkCity' in view and 'NXGothicBackdrop()' in app and 'NXGothicBackdrop()' in view
for name in ('NexoraDarkCity','NexoraMark','NexoraBanner','NexoraPanelBackdrop'):
    asset=root/'ThreeOneOSFive/Assets.xcassets'/f'{name}.imageset'
    contents=json.loads((asset/'Contents.json').read_text())
    for entry in contents['images']:
        if entry.get('filename'): assert (asset/entry['filename']).is_file(),f"Recurso ausente: {name}"
assert project.count('CURRENT_PROJECT_VERSION = 16;')==2
assert project.count('MARKETING_VERSION = 2.0.5;')==2
assert 'HOLOGRAMA PERSONAJE RAINBOW' in view
print('OK: interfaz roja Build 12, dos pantallas y recursos validados.')
