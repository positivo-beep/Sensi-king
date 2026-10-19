#!/usr/bin/env python3
"""Revisión estática de integración del flujo de actualización.
No reemplaza compilación Xcode, tests macOS o pruebas iPhone.
"""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
app=root/'ThreeOneOSFive'
models=(app/'helpers/PatchProjectModels.swift').read_text()
engine=(app/'helpers/PatchTransaction.swift').read_text()
ui=(app/'ContentView.swift').read_text()
editor=(app/'views/PatchProjectEditorView.swift').read_text()
codec=(app/'helpers/PatchPackageCodec.swift').read_text()
tests=(root/'scripts/PruebaMotorTransacciones.swift').read_text()
assert 'expectedOriginalSHA256: String?' in models
assert 'case updatedReplacementRequired' in models
assert 'case incompatibleOriginalVersion' in models
assert 'let actual = try? digestFile(item.target)' in engine
assert 'if !versionChanges.isEmpty' in engine
assert 'digest(item.rule.replacementData) == older.replacementDigest' in engine
assert 'throw PatchPackageError.updatedReplacementRequired' in engine
assert 'throw PatchPackageError.incompatibleOriginalVersion' in engine
assert 'previousOriginalVersions(' in engine
assert 'guard backupDigest == originalDigestBefore' in engine
assert 'Importar paquete actualizado' in ui
assert 'Usar archivo actual y continuar' not in ui
assert 'applyWithAcceptedCurrentOriginal' not in ui
assert 'showOriginalImporter' in editor
assert 'reader.read(upToCount: 1_048_576)' in editor
assert 'expectedOriginalSHA256: expectedOriginalSHA256' in editor
assert 'if let hash = rule.expectedOriginalSHA256' in codec
assert 'Bloqueo de hash original incompatible en primera aplicacion' in tests
assert 'Bloquear payload antiguo aunque se actualice su SHA vinculado' in tests
assert 'allowUpdatedOriginal: true' in tests, 'Un test debe probar que la anulacion antigua ya no salta el bloqueo'
print('INTEGRACIÓN V2.1.4 OK: editor + datos .3105 + preflight + bloqueo de obsoletos + pruebas macOS previstas')
