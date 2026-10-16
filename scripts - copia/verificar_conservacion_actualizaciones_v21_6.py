#!/usr/bin/env python3
"""Preflight estático de V21.6; no sustituye integración iOS real."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
e=(r/'ThreeOneOSFive/helpers/PatchTransaction.swift').read_text()
s=(r/'ThreeOneOSFive/helpers/DevicePatchService.swift').read_text()
v=(r/'ThreeOneOSFive/ContentView.swift').read_text()
assert 'case externalUpdatePreserved' in e
assert 'preserveExternallyChangedTargets: Bool = false' in e
assert 'let preservedPaths = Set(' in e
assert 'journal.status = preservedDigests.isEmpty ? .restored : .externalUpdatePreserved' in e
assert r'return preservedChanges.map(\.displayPath)' in e
assert 'preservedChangedFiles: preserved' in s
assert 'preserveExternallyChangedTargets: !allowChangedTargets' in v
assert 'inspection.changedTargets.contains(where: { $0.kind == .missing })' in v
assert (r/'ThreeOneOSFive/Assets.xcassets/NexoraActivation.dataset/opcion_activada_audio.mp3').is_file()
print('OK V21.6: conservación ante cambios externos; archivo ausente detiene operación; sonido conservado.')
print('Pendiente: compilar en Xcode/GitHub Actions y verificar con archivos de prueba propios.')
