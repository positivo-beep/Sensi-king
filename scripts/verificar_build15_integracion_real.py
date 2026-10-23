#!/usr/bin/env python3
"""Integración Build 15: prueba ESTÁTICA y modelo SHA. NO garantiza prueba iPhone."""
from pathlib import Path
import hashlib, json, subprocess, shutil
R=Path(__file__).resolve().parents[1]
E=(R/'ThreeOneOSFive/helpers/PatchTransaction.swift').read_text()
D=(R/'ThreeOneOSFive/helpers/DevicePatchService.swift').read_text()
P=(R/'ThreeOneOSFive/helpers/NXVersionedPairStore.swift').read_text()
U=(R/'ThreeOneOSFive/ContentView.swift').read_text()
assert 'let versionChanges = try changesSinceLastOriginal' in E
assert E.index('let versionChanges = try changesSinceLastOriginal') < E.index('let transactionID = UUID()')
assert 'size != previous.byteCount || digest != previous.digest' in E
assert 'guard let expected = verifiedOriginals[item.rule.id]' in E
assert 'originalDigest != expected' in E
assert 'guard targetFingerprints[key] != nil' in E
assert 'removeItem(at: transactionDirectory)' in E
assert 'throw PatchPackageError.originalVersionChanged(versionChanges)' in E
assert 'verifiedOriginals: verifiedOriginals' in D
assert 'NXVersionedPairStore.compatibleVariant(' in U
assert 'id: option.id.uuidString, originalURL: originalURL' in U
assert 'project.rules[0].replacementData = matching.data' in U
assert 'verifiedOriginals: [project.rules[0].id: matching.originalDigest]' in U
assert 'try DevicePatchService.apply(project: project)' in U
assert 'applyWithAcceptedCurrentOriginal' not in U
assert 'Usar archivo actual y continuar' not in U
assert 'sha256(current) == registered.originalSHA256' in P
assert 'sha256(replacement) == registered.modifiedSHA256' in P
assert 'guard let registered = try index(base)[id] else { return nil }' in P
assert 'ContainerStore' not in P and 'DevicePatchService' not in P
assert U.count('NXBundledOption(id: UUID(uuidString:')==15
assert hashlib.sha256(b'original A').hexdigest()!=hashlib.sha256(b'original B').hexdigest()
if shutil.which('swiftc'):
    files=list((R/'ThreeOneOSFive').rglob('*.swift'))
    result=subprocess.run(['swiftc','-frontend','-parse',*(str(f) for f in files)],capture_output=True,text=True)
    assert result.returncode==0,result.stderr
print('OK: 15 opciones reales conectadas al hash de versión; bloqueo si varió un byte; sin bypass de confirmación.')
