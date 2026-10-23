from pathlib import Path
r=Path(__file__).resolve().parents[1]
a=(r/'ThreeOneOSFive/App.swift').read_text()
s=(r/'ThreeOneOSFive/ContentView.swift').read_text()
# Retain exactly the baseline login code. Monitoring lives in ContentView.
assert 'https://hypersex-licencias-propias.nexora-system26.workers.dev' in a
assert 'NexoraSecureStorage.save(formatted, licenseAccount)' in a
assert 'makeContent().environmentObject(model)' in a
assert '35_000_000_000' in a and 'guard activeRequestNumber == requestNumber else { return }' in a
assert '.task(id: nxScenePhase == .active && periodicAuditEnabled && license.state == .allowed)' in s
assert '30_000_000_000' in s and '300_000_000_000' in s
assert 'NXSettingsView(music: music, onCheckOriginals: checkOriginalsOnForeground)' in s
assert 'isChanged(option.targetPath)' in s
assert 'if enabled, let project = item.project' in s
assert 'Verificación incompleta; no se bloquearon otras opciones.' in s
print('OK: endpoint, Keychain y acceso preservados; watchdog y vigilancia aislada del login.')
