#!/usr/bin/env python3
"""Bloquea releases con etiquetas de IPA que no corresponden a la versión real."""
from pathlib import Path
import plistlib
import re

repo = Path(__file__).resolve().parents[2]
project = repo / 'ThreeOneOSFive'
plist = plistlib.loads((project / 'ThreeOneOSFive/Info.plist').read_bytes())
version = plist['CFBundleShortVersionString']
build = str(plist['CFBundleVersion'])
assert re.fullmatch(r'\d+\.\d+\.\d+', version), 'Versión mal formada'
assert re.fullmatch(r'\d+', build), 'Build mal formado'
expected = f'NEXORA_SYSTEM_2026_V{version.replace(".", "_")}_BUILD{build}_sin_firmar'
for path in (repo / '.github/workflows/build-nexora-ios.yml',
             project / '.github/workflows/build-nexora-ios.yml'):
    workflow = path.read_text(encoding='utf-8')
    produced = re.findall(r'NEXORA_SYSTEM_2026_V\d+_\d+_\d+_BUILD\d+_sin_firmar', workflow)
    assert len(produced) == 4, f'Workflow contiene {len(produced)} etiquetas de IPA: {path}'
    assert all(value == expected for value in produced), f'Nombre IPA obsoleto en {path}: {produced}'
    assert 'REEMPLAZO: 16/16 comprobaciones correctas' in workflow, 'El CI no comprueba los 16 casos'

pbx = (project / 'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
assert pbx.count(f'MARKETING_VERSION = {version};') >= 2, 'Xcode desincronizado'
assert pbx.count(f'CURRENT_PROJECT_VERSION = {build};') >= 2, 'Build Xcode desincronizado'
release = (project / 'scripts/verificar_release_nueva_nexora.py').read_text(encoding='utf-8')
ipa_check = (project / 'scripts/verificar_ipa_generada.py').read_text(encoding='utf-8')
assert f"== '{version}'" in release and f"== '{build}'" in release, 'Verificador de release desactualizado'
assert f"=='{version}'" in ipa_check and f"=='{build}'" in ipa_check, 'Verificador de IPA desactualizado'
print(f'VERSIÓN SINCRONIZADA: {version} build {build}; nombres IPA, Xcode y CI correctos.')
