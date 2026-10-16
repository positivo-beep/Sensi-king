#!/usr/bin/env python3
"""Prueba local de limpieza de temporales de NEXORA, sin acceso a otras apps."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parent.parent
engine = repo / 'ThreeOneOSFive/helpers/NXOwnedTemporaryWorkspaces.swift'
test = repo / 'scripts/PruebaTemporalesNX.swift'
content = (repo / 'ThreeOneOSFive/ContentView.swift').read_text()
proj = (repo / 'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
assert 'testOwnedTemporaryCleanup()' in content
assert 'Probar limpieza por opción' in content
assert '3105N200,' in proj and '3105N100 /* NXOwnedTemporaryWorkspaces.swift */' in proj
assert 'no borra respaldos, registros ni datos externos' in content
assert engine.exists() and test.exists()
service = (repo / 'ThreeOneOSFive/helpers/DevicePatchService.swift').read_text()
assert 'NXOwnedTemporaryWorkspaces.clean(optionID: receipt.projectID)' in service
assert 'let cleanup = try DevicePatchService.restore(' in content
with tempfile.TemporaryDirectory() as td:
    binary = Path(td) / 'nx-owned-workspace-test'
    subprocess.run(['swiftc', '-o', str(binary), str(engine), str(test)], check=True)
    subprocess.run([str(binary)], check=True)
print('OK: módulo registrado en Xcode, UI de diagnóstico y pruebas reales de temporales')
