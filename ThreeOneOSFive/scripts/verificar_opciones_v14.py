#!/usr/bin/env python3
"""NEXORA V14: valida el catálogo y los recursos incorporados. No reemplaza Xcode ni iPhone."""
from pathlib import Path
import json, hashlib, re
root=Path(__file__).resolve().parent.parent
catalog=json.loads((root/'NEXORA_V14_MAPA_DE_OPCIONES.json').read_text())
ui=(root/'ThreeOneOSFive/ContentView.swift').read_text()
assets=root/'ThreeOneOSFive/Assets.xcassets'
assert len(catalog) == 21, f'El catálogo esperaba 21 opciones: {len(catalog)}'
assert len({entry['opcion'] for entry in catalog})==len(catalog), 'Nombres duplicados'
assert 'private func activeConflict(' in ui, 'Falta exclusión mutua de destinos'
assert 'DevicePatchService.apply(project:' in ui
assert 'DevicePatchService.restore(' in ui
assert 'Toggle(name, isOn: .constant(false))' in ui, 'Las opciones pendientes no deben habilitarse'
for e in catalog:
    assert e['opcion'] in ui, e['opcion']
    if e['recurso']:
        d=assets/(e['recurso']+'.dataset')
        info=json.loads((d/'Contents.json').read_text())
        filename=info['data'][0]['filename']
        payload=(d/filename).read_bytes()
        assert hashlib.sha256(payload).hexdigest()==e['sha256'], e['opcion']
        assert len(payload)==e['tamano_bytes'], e['opcion']
    elif e['estado']=='generado':
        assert e['opcion']=='ANTENA SOLA' and e['destino_relativo'], e['opcion']
    else:
        assert e['estado']=='pendiente' and e['destino_relativo'] is None, e['opcion']
print('OK: %d opciones (%d con recursos, %d pendientes); motor y UI presentes.' % (len(catalog),sum(bool(e['recurso']) for e in catalog),sum(e['estado']=='pendiente' for e in catalog)))
print('Pendiente: compilación Xcode, verificación de acceso real y restauración en iPhone.')
