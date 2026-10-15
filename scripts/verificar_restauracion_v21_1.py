#!/usr/bin/env python3
"""Preflight de integración V21.1: comprueba la ruta de verificación posterior."""
from pathlib import Path
src = Path(__file__).resolve().parents[1] / 'ThreeOneOSFive/helpers/PatchTransaction.swift'
s = src.read_text()
restore = s.split('static func restore(', 1)[1].split('static func resetToAppliedState(', 1)[0]
verify = s.split('private static func verifyRestoredContent(', 1)[1].split('private static func resolvedCreatedDirectories(', 1)[0]
assert 'try verifyRestoredContent(resolved, fileManager: fileManager)' in restore
assert restore.index('try verifyRestoredContent(') < restore.index('journal.status = .restored')
assert 'try digestFile(item.target) == expected' in verify
assert 'if fileManager.fileExists(atPath: item.target.path)' in verify
assert 'throw PatchPackageError.restoreFailed' in verify
assert 'try withCurrentStateRecovery(' in restore
assert 'let synthesizer = AVSpeechSynthesizer()' in (src.parents[1] / 'ContentView.swift').read_text()
print('OK: verificación SHA-256 antes de registrar restauración y audio V21 presentes')
