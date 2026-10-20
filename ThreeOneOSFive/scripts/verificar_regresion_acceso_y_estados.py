#!/usr/bin/env python3
"""Comprobaciones estáticas. NO prueban permisos de otro contenedor en iPhone."""
from pathlib import Path
base = Path(__file__).resolve().parents[1]
active = (base/'ThreeOneOSFive/ContentView.swift').read_text()
copy = (base/'ContentView.swift').read_text()
app = (base/'ThreeOneOSFive/App.swift').read_text()
assert copy == active, "Copias de interfaz divergentes"
assert (base/'App.swift').read_text() == app, "Copias de App divergentes"
assert 'lastPatchAppliedThisSession = false' in app
assert 'lastPatchAppliedThisSession = true' in active
assert 'iOS reconocido · Acceso no verificado' in active
assert 'Text(appState.isSupported ? "Sistema en línea"' not in active
assert r'No se pudo acceder al contenedor necesario para «\(title)»' in active
assert 'ANTENA SOLA no puede aplicarse de esta manera' not in active
assert 'guard FileManager.default.isReadableFile(atPath: target.path)' in active
assert 'guard FileManager.default.isWritableFile(atPath: target.path)' in active
assert 'Ver errores de activación' in active and 'LogView()' in active
assert 'showTechnicalLog' in active
assert active.count('appState.lastPatchAppliedThisSession = true') == 2
assert active.count('appState.lastPatchAppliedThisSession = false') == 2
assert 'nexora: activación fallida para' in active
assert 'nexora: error al activar paquete' in active
assert 'NXModHoloPjRainbow' in active
print('REGRESIÓN DE ESTADOS: 13 verificaciones estáticas superadas. Permisos externos: NO verificados.')
