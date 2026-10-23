#!/usr/bin/env python3
"""Verificaciones estáticas de no regresión del panel de entrada.
No sustituyen pruebas reales en Xcode o en el iPhone.
"""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
a=(r/'ThreeOneOSFive/App.swift').read_text(encoding='utf-8')
c=(r/'ThreeOneOSFive/ContentView.swift').read_text(encoding='utf-8')
s=(r/'ThreeOneOSFive/helpers/PatchProjectStore.swift').read_text(encoding='utf-8')
assert 'makeContent().environmentObject(model)' in a, 'El panel debe esperar autorización de Cloudflare'
assert 'result.ok && result.active' in a, 'El servidor es quien permite entrar'
assert 'guard activeRequestNumber == requestNumber else { return }' in a
assert 'licenseSession.data(for: request)' in a
assert 'Task.sleep(nanoseconds: 30_000_000_000)' in c
assert 'Task.sleep(nanoseconds: 300_000_000_000)' in c
assert 'Task.detached(priority: .utility)' in c
assert 'guard !originalAuditIsRunning, busyProject == nil' in c
assert 'guard license.state == .allowed, nxScenePhase == .active else { return }' in c
assert 'Task.sleep(nanoseconds: 1_000_000_000)' in c
assert 'guard !Task.isCancelled, nxScenePhase == .active,' in c
assert c.count('ownedUpdater.checkWhenActive()') == 2
assert 'store.reload()' not in c.split('            .onAppear {\n                // La biblioteca', 1)[1].split('            .task {', 1)[0], 'No duplicar recarga de paquetes en el primer dibujo'
assert 'let loadedItems = PatchProjectLibrary.load()' in s and 'finishInitialLoad(loadedItems)' in s
print('OK: sin recarga duplicada, catálogo diferido, verificación Cloudflare intacta y vigilancia aislada.')
