#!/usr/bin/env python3
"""Pruebas estáticas y criptográficas de la entrega; no prueba iOS ni Cloudflare."""
from pathlib import Path
import base64, json, subprocess, sys, tempfile, hashlib
r=Path(__file__).resolve().parents[1]
a=(r/'ThreeOneOSFive/App.swift').read_text()
c=(r/'ThreeOneOSFive/ContentView.swift').read_text()
u=(r/'ThreeOneOSFive/helpers/NXOwnedResourceUpdater.swift').read_text()
assert 'makeContent().environmentObject(model)' in a
assert 'guard activeRequestNumber == requestNumber else { return }' in a
assert 'self?.endHungRequest(requestNumber)' in a
assert '35_000_000_000' in a and 'licenseSession.data(for: request)' in a
assert '&& license.state == .allowed)' in c
assert 'Task.sleep(nanoseconds: 30_000_000_000)' in c
assert 'Task.sleep(nanoseconds: 300_000_000_000)' in c
assert 'guard license.state == .allowed, nxScenePhase == .active else { return }' in c
assert 'if requiresUpdatedPair && matching == nil' in c
assert 'if !signed && !(manifest.compatiblePairs ?? []).isEmpty' in u
assert u.index('if !signed && !(manifest.compatiblePairs ?? []).isEmpty') < u.index('let directory = try Self.resourceDirectory()')
assert 'key.isValidSignature(signature, for: payload)' in u
assert 'guard keyText.isEmpty else { throw NXUpdateFailure.unsignedManifest }' in u
records=json.loads((r/'NEXORA_INVENTARIO_SHA256.json').read_text())
for path,digest in records.items():
    assert hashlib.sha256((r/path).read_bytes()).hexdigest()==digest,path
try:
    import cryptography  # Dependencia opcional para el test criptográfico, no para compilar NEXORA.
except ImportError:
    print('AVISO: cryptography no instalado; prueba de firma omitida en esta máquina.')
else:
    cmd=[sys.executable,str(r/'scripts/firmar_catalogo_nexora.py')]
    with tempfile.TemporaryDirectory() as temp:
        t=Path(temp)
        private=t/'secret.pem'; public=t/'public.txt'; plain=t/'manifest.json'; signed=t/'signed.json'
        plain.write_text(json.dumps({'schema':1,'resources':[]}))
        def run(args,expect=0):
            p=subprocess.run(cmd+args,text=True,capture_output=True)
            assert p.returncode==expect,(p.stdout,p.stderr)
        run(['generar','--private',str(private),'--public',str(public)])
        assert len(base64.b64decode(public.read_text().strip()))==32
        run(['firmar','--private',str(private),'--manifest',str(plain),'--output',str(signed)])
        run(['verificar','--public',str(public),'--catalogo',str(signed)])
        record=json.loads(signed.read_text())
        record['payloadBase64']=base64.b64encode(b'{"schema":1,"resources":[1]}').decode()
        signed.write_text(json.dumps(record))
        run(['verificar','--public',str(public),'--catalogo',str(signed)],expect=1)
print('OK: login no bloqueante, auditoría aislada, cambios solo con pareja compatible, firma válida/alterada e inventario.')
