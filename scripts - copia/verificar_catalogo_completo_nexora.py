#!/usr/bin/env python3
"""Auditoría de INTEGRIDAD e interfaz antes de Xcode (no prueba permisos iOS)."""
from pathlib import Path
import json, re, hashlib, struct
r=Path(__file__).resolve().parents[1]
ui=(r/'ThreeOneOSFive/ContentView.swift').read_text()
entries=re.findall(r'NXBundledOption\(id: UUID\(uuidString: "([^"]+)"\)!, title: "([^"]+)", category: "([^"]+)", dataAsset: "([^"]+)", targetPath: "([^"]+)", filename: "([^"]+)"\)',ui)
assert len(entries)==11, f'La UI debe contener 11 opciones con recurso: {len(entries)}'
assert len({e[0] for e in entries})==len(entries), 'UUID duplicados'
assert len({e[1] for e in entries})==len(entries), 'Nombres duplicados'
cat=json.loads((r/'NEXORA_V14_MAPA_DE_OPCIONES.json').read_text())
assert len(cat)==21, 'Catálogo de 21 opciones incompleto'
assert len({i['opcion'] for i in cat})==len(cat), 'Catálogo duplicado'
active={e[1]:e for e in entries}
assets=r/'ThreeOneOSFive/Assets.xcassets'
for item in cat:
    name=item['opcion']
    assert name in ui, f'Falta mostrar {name}'
    if item['recurso']:
        assert name in active, f'Recurso presente sin opción en UI: {name}'
        id,title,category,asset,path,filename=active[name]
        assert item['categoria']==category and item['recurso']==asset and item['destino_relativo']==path, f'Mapa/UI desincronizados: {name}'
        data_dir=assets/(asset+'.dataset')
        meta=json.loads((data_dir/'Contents.json').read_text())
        assert len(meta['data'])==1, f'Dataset inválido: {name}'
        datapath=data_dir/meta['data'][0]['filename']
        binary=datapath.read_bytes()
        assert len(binary)==item['tamano_bytes'] and hashlib.sha256(binary).hexdigest()==item['sha256'], f'Hash/longitud incorrectos: {name}'
        assert binary.startswith(b'UnityFS\x00'), f'Cabecera inesperada: {name}'
        assert filename==path.split('/')[-1],f'Nombre de destino incompatible: {name}'
        assert item['estado']=='incluido', f'Estado obsoleto: {name}'
    else:
        assert name not in active and item['estado']=='pendiente' and item['destino_relativo'] is None, f'Pendiente activado por error: {name}'
blue=active['HOLOGRAMA PERSONAJE AZUL']
yellow=active['HOLOGRAMA PERSONAJE AMARILLO']
assert blue[4]==yellow[4] and blue[3]!=yellow[3], 'Azul y amarillo deben compartir destino con recursos separados'
assert next(i for i in cat if i['opcion']=='HOLOGRAMA PERSONAJE AZUL')['sha256']=='711375e0b39aed9ea18e6956bbc8ebda82e902925842b8202a1b34a86f88805d', 'El recurso azul no coincide con el enviado por el usuario'
assert 'private func activeConflict(' in ui and 'activeConflict(bundleID:' in ui, 'Falta bloqueo de destinos compartidos'
assert 'try option.checkOriginalExists()' in ui and 'try DevicePatchService.apply(project: project)' in ui, 'Activación sin revisión de original'
assert 'restore(receipt: receipt)' in ui and 'preserveExternallyChangedTargets: !allowChangedTargets' in ui, 'Falta conexión de restauración protegida'
assert 'testExternalUpdatePreservation()' in ui and 'Probar protección de actualización' in ui and 'preserveExternallyChangedTargets: true' in ui and 'allowUpdatedOriginal: true' in ui, 'Falta diagnóstico nuevo de protección de actualizaciones'
assert len({e[4] for e in entries})==3, 'Número inesperado de destinos distintos'
assert len([i for i in cat if i['recurso']])==11 and len([i for i in cat if not i['recurso']])==10
print('OK: 21 opciones = 11 disponibles con recurso + 10 pendientes.')
print('OK: 11 datasets verificados con SHA-256; azul independiente del amarillo.')
print('OK: interfaz enlazada a motor, bloqueo de destinos compartidos y restauración protegida.')
print('PENDIENTE: ejecución en iPhone, permisos sobre apps externas y compatibilidad del archivo UnityFS.')
