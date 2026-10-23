#!/usr/bin/env python3
"""Verificaciones de compatibilidad SHA-256; NO prueban el runtime iOS."""
from pathlib import Path
import tempfile, subprocess, hashlib, shutil, json
R=Path(__file__).resolve().parents[1]
SERVICE=(R/'ThreeOneOSFive/helpers/NXVersionedPairStore.swift').read_text()
UPDATER=(R/'ThreeOneOSFive/helpers/NXOwnedResourceUpdater.swift').read_text()
UI=(R/'ThreeOneOSFive/ContentView.swift').read_text()
PBX=(R/'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
assert 'NXVersionedPairStore.swift in Sources' in PBX
assert 'NXCompatibleResourcePair' in SERVICE
assert 'modifiedForOriginalSHA256 == pair.original.sha256' in SERVICE
assert 'sha256(original) == remote.original.sha256' in SERVICE
assert 'sha256(modified) == remote.modified.sha256' in SERVICE
assert 'try verifiedURLs(id: id).modified' in SERVICE
assert 'sha256(original) == entry.originalSHA256' in SERVICE
assert 'sha256(modified) == entry.modifiedSHA256' in SERVICE
assert 'saved[remote.id] = next' in SERVICE
assert 'JSONEncoder().encode(saved).write(to: indexURL(base), options: .atomic)' in SERVICE
assert 'No "reparar" automáticamente un original alterado' in SERVICE
assert 'NexoraOwnedResources' in SERVICE
assert 'ContainerStore' not in SERVICE and 'DevicePatchService' not in SERVICE
assert 'try NXVersionedPairStore.install(pair,' in UPDATER
assert 'try NXVersionedPairStore.validate(pair)' in UPDATER
assert 'ownedUpdater.inspectCompatibility()' in UI
assert 'ownedUpdater.runOwnedPairDemo(activate: true)' in UI
assert 'ownedUpdater.runOwnedPairDemo(activate: false)' in UI
if shutil.which('swiftc'):
    swift=list((R/'ThreeOneOSFive').rglob('*.swift'))
    cmd=['swiftc','-frontend','-parse',*(str(x) for x in swift)]
    p=subprocess.run(cmd,capture_output=True,text=True)
    assert p.returncode==0,p.stderr
if shutil.which('node'):
    with tempfile.TemporaryDirectory() as d:
        script=Path(d)/'check.mjs'
        script.write_text(r'''
import {pathToFileURL} from 'node:url';
const worker = (await import(pathToFileURL(process.argv[2]).href)).default;
const host='https://updates.example.workers.dev';
const request=async p=>worker.fetch(new Request(host+p));
const resp=await request('/manifest.json'); if(resp.status!==200)throw new Error('manifest');
const catalog=await resp.json();if(catalog.schema!==1)throw new Error('schema');
const pair=catalog.compatiblePairs[0]; if(pair.id!=='nexora-demo')throw new Error('missing pair');
const hash=async data => [...new Uint8Array(await crypto.subtle.digest('SHA-256',data))].map(x=>x.toString(16).padStart(2,'0')).join('');
const r1=await request(pair.original.url),r2=await request(pair.modified.url);
const original=await r1.arrayBuffer(),variant=await r2.arrayBuffer();
const baseHash=await hash(original),variantHash=await hash(variant);
if(baseHash!==pair.original.sha256 || variantHash!==pair.modified.sha256)throw new Error('bad digest');
if(pair.modifiedForOriginalSHA256!==baseHash)throw new Error('not pinned');
if(original.byteLength!==pair.original.bytes || variant.byteLength!==pair.modified.bytes)throw new Error('bad size');
const changed=new Uint8Array(original.slice(0));changed[0]^=1;
if(await hash(changed)===baseHash)throw new Error('1 byte change undetected');
if(await hash(changed)===pair.modifiedForOriginalSHA256)throw new Error('invalid pair accepted');
const damaged=new Uint8Array(variant.slice(0));damaged[0]^=1;
if(await hash(damaged)===pair.modified.sha256)throw new Error('damage undetected');
const fail=await request('/missing');if(fail.status!==404)throw new Error('bad path');
console.log('Catálogo y bytes: original, variante, un byte cambiado, tamper y HTTP 404 OK');
''')
        p=subprocess.run(['node',str(script),str(R/'deploy/nexora-updates-worker.mjs')],capture_output=True,text=True)
        assert p.returncode==0,p.stderr
        print(p.stdout.strip())
print('Build 14: comprobaciones de estructura y ejemplos OK')
