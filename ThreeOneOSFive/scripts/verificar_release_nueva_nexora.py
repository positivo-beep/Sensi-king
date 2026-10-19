#!/usr/bin/env python3
"""Verifica que esta sea una entrega NUEVA, no la compilación del commit anterior.
No certifica funciones sobre iPhone ni compatibilidad de recursos externos.
"""
from pathlib import Path
import hashlib, plistlib, re

repo = Path(__file__).resolve().parents[2]
project = (repo / 'ThreeOneOSFive/ThreeOneOSFive.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
plist = plistlib.loads((repo / 'ThreeOneOSFive/ThreeOneOSFive/Info.plist').read_bytes())
engine = (repo / 'ThreeOneOSFive/ThreeOneOSFive/helpers/NXAntennaOnlyUnityFS.swift').read_text(encoding='utf-8')
assert plist['CFBundleShortVersionString'] == '2.1.6', 'Info.plist no es la versión nueva 2.1.6'
assert plist['CFBundleVersion'] == '15', 'Info.plist no es el build 15'
assert project.count('MARKETING_VERSION = 2.1.6;') >= 2, 'Xcode usa un número de versión viejo'
assert project.count('CURRENT_PROJECT_VERSION = 15;') >= 2, 'Xcode usa un build viejo'
assert 'info.replaceSubrange(0..<16, with: Array(md5))' in engine, 'Falta la corrección de MD5 de ANTENA SOLA'
assert 'com.nexora.system2026' in project, 'Bundle ID de NEXORA incorrecto'
print('RELEASE NUEVA VERIFICADA: versión 2.1.6, build 15, fuente MD5 corregida, bundle ID propio.')
