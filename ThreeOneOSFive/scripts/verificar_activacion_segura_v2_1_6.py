#!/usr/bin/env python3
"""Verificación de integración estructural. No sustituye las pruebas macOS/iPhone."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
engine = (root / 'ThreeOneOSFive/helpers/PatchTransaction.swift').read_text()
service = (root / 'ThreeOneOSFive/helpers/DevicePatchService.swift').read_text()
ui = (root / 'ThreeOneOSFive/views/PatchProjectsView.swift').read_text()
tests = (root / 'scripts/PruebaMotorTransacciones.swift').read_text()
workflow = (root / '.github/workflows/build-nexora-ios.yml').read_text()
assert 'try DevicePatchService.apply(project: project)' in ui, 'Botón activar no llama al servicio'
assert 'try PatchTransaction.apply(' in service, 'Servicio no ejecuta el motor de transacciones'
assert 'var writtenIndices: [Int] = []' in engine
assert 'writtenIndices.append(index)' in engine
assert 'for index in writtenIndices.reversed()' in engine
assert 'if journal.status == .prepared {' in engine
assert 'unknownPreparedTargets' in engine
assert 'cambió durante la activación; no se sobrescribió' in engine
assert 'try digestFile(target) == record.replacementDigest' in engine
assert 'journal.status = .rolledBack' in engine
assert 'throw PatchPackageError.updatedReplacementRequired' in engine
for case in (
    'No sobrescribir original actualizado justo al activar',
    'Revertir primer archivo sin borrar cambio externo en segundo',
    'Archivo nuevo que apareció antes de activar queda intacto',
    'No pisar cambio externo de archivo ya aplicado al fallar después',
):
    assert case in tests, f'Falta prueba: {case}'
assert '21/21 casos correctos' in workflow
print('ACTIVACIÓN V2.1.6 OK: ruta del botón, protección anti-sobrescritura, rollback selectivo, 21 pruebas locales del motor listas para repetirse en macOS')

assert 'mutationLock = NSRecursiveLock()' in engine
assert 'try withMutationLock' in engine
assert 'containsUnverifiableJournal' in engine
assert 'journal.projectID == projectID' in engine
assert 'journal.transactionID == transactionID' in engine
assert 'Diario corrupto bloquea nueva activación' in tests
assert 'Activación concurrente de opciones' in tests
print('HISTORIAL V2.1.6 OK: comprobación fail-closed y bloqueo de operaciones paralelas. Pruebas 21/21 exigidas en CI.')

ui=(root/'ThreeOneOSFive/ContentView.swift').read_text()
service=(root/'ThreeOneOSFive/helpers/DevicePatchService.swift').read_text()
assert 'DevicePatchService.activationErrorMessage(error)' in ui
assert 'patchError == .unverifiableJournal' in service
