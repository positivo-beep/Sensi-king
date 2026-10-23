#!/usr/bin/env python3
"""Static regression: verifies newly imported assets and guards original features.
A green result does not verify iOS permission or runtime activation.
"""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
ui=(root/'ThreeOneOSFive/ContentView.swift').read_text(encoding='utf-8')
cat=json.loads((root/'NEXORA_V14_MAPA_DE_OPCIONES.json').read_text(encoding='utf-8'))
assets=root/'ThreeOneOSFive/Assets.xcassets'
assert len(cat)==21
assert len(set(c['opcion'] for c in cat))==len(cat)
for name in ('HOLOGRAMA PERSONAJE RAINBOW','HOLOGRAMA PERSONAJE AZUL','RAINBOW COLOR ROJO'):
 c=next(x for x in cat if x['opcion']==name)
 assert c['estado']=='incluido' and c['recurso']
 assert ui.count('title: "'+name+'"')==1, name
 directory=assets/(c['recurso']+'.dataset')
 filename=json.loads((directory/'Contents.json').read_text())['data'][0]['filename']
 raw=(directory/filename).read_bytes()
 assert hashlib.sha256(raw).hexdigest()==c['sha256']
 assert len(raw)==c['tamano_bytes']
assert 'title: "HOLOGRAMA PERSONAJE ROJO"' not in ui
assert '"HOLOGRAMA PERSONAJE ROJO"' not in ui
# Se retiró Verde y la cuarta plaza corresponde a Oscuro Rainbow.
# Esta prueba debe seguir la interfaz actual, no exigir el texto de Build 16.
assert '"HOLOGRAMA PERSONAJE VERDE"' not in ui, 'La fila Verde antigua no debe estar en el panel'
assert ui.count('title: "HOLOGRAMA PERSONA OSCURO RAINBOW OSCURO"') == 1, 'Debe existir el holograma Oscuro Rainbow como cuarta opcion'
assert len([line for line in ui.splitlines() if 'NXBundledOption(' in line and 'category: "HOLO PJ"' in line]) == 4, 'HOLO PJ debe contener cuatro opciones'
assert 'NXModHoloPjAmarillo' in ui
assert 'DevicePatchService.apply(project:' in ui
assert 'DevicePatchService.restore(' in ui
pbx=(root/'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
assert pbx.count('PRODUCT_BUNDLE_IDENTIFIER = "com.apple.mobile.MobileHouseArrest";')==2
assert pbx.count('CURRENT_PROJECT_VERSION = 16;')==2
print('OK: catálogo, 3 recursos importados, Rainbow reemplaza Rojo; identidad original conservada.')
print('PENDIENTE: compilación en macOS y prueba real en iPhone.')

# Solo los dos servicios de limpieza se refuerzan; ninguna vía de acceso,
# reemplazo ni restauración del Build 8 se sobrescribe con Build 18.
engine=json.loads((root/'NEXORA_BASE_BUILD8_SHA256.json').read_text())
cleaning=json.loads((root/'NEXORA_MEJORAS_SEGURAS_SHA256.json').read_text())
presentation=json.loads((root/'NEXORA_BUILD12_PRESENTACION_SHA256.json').read_text())
update13=json.loads((root/'NEXORA_BUILD13_UI_SHA256.json').read_text())
update14=json.loads((root/'NEXORA_BUILD14_UI_SHA256.json').read_text())
update15=json.loads((root/'NEXORA_BUILD15_CAMBIOS_SHA256.json').read_text())
update16=json.loads((root/'NEXORA_BUILD16_CAMBIOS_SHA256.json').read_text())
alok=json.loads((root/'NEXORA_ALOK_CAMBIOS_SHA256.json').read_text())
manifest=json.loads((root/'NEXORA_INVENTARIO_SHA256.json').read_text())
assert set(presentation)=={'ThreeOneOSFive/App.swift','ThreeOneOSFive/ContentView.swift'}
for rel, expected in engine.items():
    actual=hashlib.sha256((root/rel).read_bytes()).hexdigest()
    current_expected = manifest[rel] if rel in ('ThreeOneOSFive/App.swift', 'ThreeOneOSFive/ContentView.swift') else alok.get(rel, update16.get(rel, update15.get(rel, update14.get(rel, update13.get(rel, presentation.get(rel, cleaning.get(rel, expected)))))))
    assert actual==current_expected, 'Archivo protegido alterado: '+rel
for rel, expected in cleaning.items():
    assert rel in engine and expected != engine[rel], 'Mejora de limpieza no registrada: '+rel
print('OK: motor original preservado; 2 módulos de limpieza reforzados, 2 archivos UI autorizados con SHA.')
