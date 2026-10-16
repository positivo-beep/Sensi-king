#!/usr/bin/env python3
"""Comprobaciones locales: ninguna requiere macOS. NO sustituyen compilar en Xcode."""
from pathlib import Path
import plistlib, zipfile, json
ROOT = Path(__file__).resolve().parent.parent
swift = list((ROOT/'ThreeOneOSFive').rglob('*.swift'))
assert len(swift)>=50, f'Fuentes incompletas: {len(swift)}'
a=(ROOT/'ThreeOneOSFive/App.swift').read_text()
c=(ROOT/'ThreeOneOSFive/ContentView.swift').read_text()
assert 'NexoraLicenseBoundary' in a and 'NexoraKeyScreen' in a
assert 'hypersex-licencias-propias.nexora-system26.workers.dev' in a
assert '/v1/activate' in a and '/v1/validate' in a
assert 'case .allowed:' in a and 'case .locked:' in a
assert 'lockIfExpired' in a and 'revalidateOnReturn' in a
assert 'expires_at' in a and 'duration_days' in a
assert 'DevicePatchService.apply(' in c
assert 'DevicePatchService.restore(' in c
assert 'private var categoryTabs:' in c and 'ScrollView(.horizontal' in c
assert 'private var installedPatchSection:' in c
for option in ['AIMDRAG','AIMBOT CABEZA','AIMBOT CUELLO','AIMBOT PECHO','BALAS MÁGICA']:
    assert option in c, option
assert 'missingPackageRow' in c and '.disabled(true)' in c
assert 'NXLocalMotorDemo.setEnabled' in c
assert 'NXMotorOriginal' in c and 'NXMotorModificado' in c
assert 'Settings' in c or 'Configuración' in c
assert (ROOT/'ThreeOneOSFive/helpers/DevicePatchService.swift').is_file()
assert (ROOT/'ThreeOneOSFive/helpers/PatchTransaction.swift').is_file()
assert (ROOT/'ThreeOneOSFive/helpers/ContainerStore.swift').is_file()
assert (ROOT/'ThreeOneOSFive.xcodeproj/xcshareddata/xcschemes/NEXORA_SYSTEM_2026.xcscheme').is_file()
plist = plistlib.loads((ROOT/'ThreeOneOSFive/Info.plist').read_bytes())
assert plist['CFBundleDisplayName']=='NEXORA SYSTEM 2026'
assert plist['MinimumOSVersion']=='16.0'
for asset in ['NexoraMark.imageset','NexoraBanner.imageset','NexoraPulse.dataset','NXMotorOriginal.dataset','NXMotorModificado.dataset']:
    d=ROOT/'ThreeOneOSFive/Assets.xcassets'/asset
    info=json.loads((d/'Contents.json').read_text())
    assert any((d/x['filename']).is_file() for k in ('images','data') for x in info.get(k,[]) if x.get('filename')), asset
print(f'NEXORA: OK comprobaciones estructurales ({len(swift)} Swift, assets, licencia, archivos, panel, esquema).')
print('ATENCIÓN: falta compilación Xcode/macOS y pruebas en iPhone.')
