#!/usr/bin/env python3
"""Revisión estática del release: no sustituye compilación con macOS ni ejecución en iPhone."""
from pathlib import Path
import plistlib
repo=Path(__file__).resolve().parents[2]
project=(repo/'ThreeOneOSFive/ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
plist=plistlib.loads((repo/'ThreeOneOSFive/ThreeOneOSFive/Info.plist').read_bytes())
workflow=(repo/'.github/workflows/build-nexora-ios.yml').read_text()
workflow_alterno=(repo/'ThreeOneOSFive/.github/workflows/build-nexora-ios.yml').read_text()
engine=(repo/'ThreeOneOSFive/ThreeOneOSFive/helpers/FileReplacementService.swift').read_text()
test=(repo/'ThreeOneOSFive/scripts/PruebaReemplazoSeguro.swift').read_text()
version='NEXORA_SYSTEM_2026_V2_1_9_BUILD18_sin_firmar'
assert plist.get('CFBundleShortVersionString')=='2.1.9'
assert str(plist.get('CFBundleVersion'))=='18'
assert 'MARKETING_VERSION = 2.1.9;' in project
assert 'CURRENT_PROJECT_VERSION = 18;' in project
assert workflow==workflow_alterno, 'Workflows desincronizados'
assert version+'.ipa' in workflow and 'name: '+version in workflow
assert 'V2_1_6_BUILD15_sin_firmar' not in workflow, 'IPA antigua referenciada'
assert 'sourceChangedDuringCopy' in engine and 'targetChangedDuringCopy' in engine
assert 'lstat(url.path' in engine and 'fstat(fd' in engine
assert 'O_NOFOLLOW' in engine and 'rename(stagingURL.path, targetURL.path)' in engine
assert 'REEMPLAZO: 16/16 comprobaciones correctas' in test
assert 'reemplazo-seguro-test.log' in workflow
assert 'verificar_reemplazo_release_v2_1_9.py' in workflow
print('RELEASE 2.1.9/18 OK: fuentes, metadatos, pruebas y los dos workflows coherentes.')
