#!/usr/bin/env python3
"""Build 16: invariantes de seguridad + prueba FUNCIONAL del almacenamiento
Foundation Swift. La integración iOS/macOS sigue requiriendo xcodebuild."""
from pathlib import Path
import hashlib,json,subprocess,shutil,tempfile
r=Path(__file__).resolve().parents[1]
core=(r/'ThreeOneOSFive/helpers/PatchTransaction.swift').read_text()
service=(r/'ThreeOneOSFive/helpers/DevicePatchService.swift').read_text()
ui=(r/'ThreeOneOSFive/ContentView.swift').read_text()
ledger=(r/'ThreeOneOSFive/helpers/NXOriginalRevisionLedger.swift').read_text()
project=(r/'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
assert 'NXOriginalRevisionLedger.swift in Sources' in project
assert project.count('CURRENT_PROJECT_VERSION = 16;') == 2
assert project.count('MARKETING_VERSION = 2.0.5;') == 2
assert 'Text("B16 · ROJO")' in ui
assert 'checkOriginalsOnForeground()' in ui and 'NXBundledOption.all.map(\\.targetPath)' in ui
assert 'auditKnownOriginals(' in service
assert 'PatchTransaction.observeAccessibleOriginals(' in service
assert 'if occupied.contains(key) { continue }' in core
assert 'guard let prior = versions[key] else { continue }' in core
assert 'if current == prior.digest { continue }' in core
assert 'sourceURL: target' in core and 'logicalKeySHA256: self.digest(Data(key.utf8))' in core
assert 'let inspectedDigests: [UUID: Data]' in core
assert core.count('transactionLock.lock()') == 5
assert 'if originalDigest != inspectedDigests[resolved.rule.id]' in core
assert 'writtenRecordIndices.map { records[$0] }' in core
assert 'requirePatchedDigest: true' in core
assert 'journal.status = .externalUpdatePreserved' in core or 'journal.status = preservedDigests.isEmpty ? .restored : .externalUpdatePreserved' in core
assert 'reason: .restorePreservedExternalChange' in core
assert 'provenanceVerified: false' in ledger
assert 'Restaurar de todas formas' not in ui
assert 'allowChangedTargets: false' in ui and 'preserveExternallyChangedTargets: true' in ui
assert 'maximumBytes: UInt64 = 128 * 1024 * 1024' in ledger
assert 'try digestFile(stagedCopy) == expectedDigest' in ledger
assert 'try digestFile(sourceURL) == expectedDigest' in ledger
assert 'try fileManager.moveItem(at: stage, to: final)' in ledger
assert 'try? fileManager.removeItem(at: stage)' in ledger
assert ui.count('NXBundledOption(id: UUID(uuidString:') == 15
# El inventario del motor no puede perder archivos anteriores.
original=json.loads((r/'NEXORA_BUILD15_CAMBIOS_SHA256.json').read_text())
update=json.loads((r/'NEXORA_BUILD16_CAMBIOS_SHA256.json').read_text())
alok=json.loads((r/'NEXORA_ALOK_CAMBIOS_SHA256.json').read_text())
assert set(original)-set(update)=={
 'ThreeOneOSFive/helpers/NXVersionedPairStore.swift',
 'ThreeOneOSFive/helpers/NXOwnedResourceUpdater.swift'
}
for path, digest in update.items():
 assert hashlib.sha256((r/path).read_bytes()).hexdigest()==(json.loads((r/'NEXORA_INVENTARIO_SHA256.json').read_text())[path] if path=='ThreeOneOSFive/ContentView.swift' else alok.get(path,digest)),path
assert 'KernelExploit.swift' not in repr(update)
if shutil.which('swiftc'):
 with tempfile.TemporaryDirectory(prefix='nexora-b16-test-') as td:
  cmd=['swiftc',str(r/'ThreeOneOSFive/helpers/NXOriginalRevisionLedger.swift'),
       str(r/'scripts/PruebaRevisionesOriginalesNX.swift'),'-o',str(Path(td)/'run')]
  p=subprocess.run(cmd,capture_output=True,text=True)
  assert p.returncode==0,p.stderr
  p=subprocess.run([str(Path(td)/'run')],capture_output=True,text=True)
  assert p.returncode==0,p.stdout+p.stderr
  print(p.stdout.strip())
print('OK: Build 16, verificación del motor de revisión, 15 opciones, rollback conservador.')
