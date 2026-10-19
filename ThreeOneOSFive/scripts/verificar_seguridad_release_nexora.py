#!/usr/bin/env python3
"""Verificación estática del código iOS activo: NO sustituye pruebas de dispositivo."""
from pathlib import Path
import plistlib, re
root=Path(__file__).resolve().parents[2]
app=root/'ThreeOneOSFive/ThreeOneOSFive'
project=(root/'ThreeOneOSFive/ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
plist=plistlib.loads((app/'Info.plist').read_bytes())
identifier='com.nexora.system2026'
assert project.count(f'PRODUCT_BUNDLE_IDENTIFIER = {identifier};')==2, 'Bundle ID debe coincidir en Debug y Release'
assert 'PRODUCT_BUNDLE_IDENTIFIER = "com.apple.mobile.MobileHouseArrest"' not in project, 'Identificador Apple reservado'
assert plist['CFBundleIdentifier']=='$(PRODUCT_BUNDLE_IDENTIFIER)', 'Info.plist debe heredar el Bundle ID de Xcode'
code=(app/'App.swift').read_text()
for mandatory in ('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly', 'persistentDeviceID()',
                  'authorizationGeneration', 'authorizationGeneration == currentGeneration',
                  'NexoraNoRedirectDelegate', 'configuration.urlCache = nil',
                  'guard let stableDeviceID = persistentDeviceID() else',
                  'state = .locked'):
    assert mandatory in code, f'Falta control de seguridad de licencias: {mandatory}'
assert 'device_id: deviceID' not in code, 'ID del dispositivo no verificado antes del envío'
assert r'No se validó la licencia (\(reason' not in code, 'Error del servidor filtrado a la interfaz'
workflow=(root/'.github/workflows/build-nexora-ios.yml').read_text()
assert 'python3 scripts/verificar_seguridad_release_nexora.py' in workflow, 'La puerta de seguridad no forma parte de CI'
assert 'python3 scripts/verificar_ipa_generada.py' in workflow, 'No se inspecciona la IPA al terminar'
print('SEGURIDAD RELEASE OK: IDs consistentes, Keychain estable, sesiones protegidas, IPA inspeccionada.')
