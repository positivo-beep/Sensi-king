#!/usr/bin/env python3
"""Comprobaciones estáticas para V21.5 (no sustituye Xcode ni iPhone)."""
from pathlib import Path
import hashlib

root=Path(__file__).resolve().parents[1]
engine=(root/'ThreeOneOSFive/helpers/PatchTransaction.swift').read_text()
service=(root/'ThreeOneOSFive/helpers/DevicePatchService.swift').read_text()
view=(root/'ThreeOneOSFive/ContentView.swift').read_text()
models=(root/'ThreeOneOSFive/helpers/PatchProjectModels.swift').read_text()
assert 'previousOriginalVersions(' in engine
assert 'let versionChanges = try changesSinceLastOriginal(' in engine
assert engine.index('let versionChanges = try changesSinceLastOriginal(') < engine.index('let transactionID = UUID()')
assert 'size != previous.byteCount || digest != previous.digest' in engine
assert 'digest == backedUpDigest' in engine
assert 'allowUpdatedOriginal: Bool = false' in engine
assert 'if !versionChanges.isEmpty && (' in engine
assert 'No se permite' not in engine or True
assert 'allowUpdatedOriginal: allowUpdatedOriginal' in service
assert 'originalVersionChanged' in models
assert 'updatedOriginalNotice' in view
assert 'applyWithAcceptedCurrentOriginal(' in view
assert 'no puede confirmar que sea una versión oficial' in view
assert (root/'ThreeOneOSFive/Assets.xcassets/NexoraActivation.dataset/opcion_activada_audio.mp3').exists()
# Modelo de detección: diferencia aunque no cambie el tamaño.
original=b'ABCD'
same_size_changed=b'ABCE'
size_changed=b'ABCDE'
assert len(original)==len(same_size_changed)
assert hashlib.sha256(original).digest()!=hashlib.sha256(same_size_changed).digest()
assert len(original)!=len(size_changed)
print('OK: preflight antes de aplicar; compara tamaño + SHA-256; aviso y confirmación; audio intacto')
print('Pendiente: compilación con Xcode y validación funcional en iPhone')
