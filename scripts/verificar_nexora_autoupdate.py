#!/usr/bin/env python3
"""Pruebas locales de configuración, manifest y aislamiento de Build 13.
No equivalen a ejecutar iOS ni a probar el servidor remoto real.
"""
from pathlib import Path
import json
import hashlib
import subprocess
import tempfile
import shutil

ROOT=Path(__file__).resolve().parents[1]
SWIFT=ROOT/'ThreeOneOSFive/helpers/NXOwnedResourceUpdater.swift'
PBX=ROOT/'ThreeOneOSFive.xcodeproj/project.pbxproj'
APP=ROOT/'ThreeOneOSFive/App.swift'
UI=ROOT/'ThreeOneOSFive/ContentView.swift'
WORKER=ROOT/'deploy/nexora-updates-worker.mjs'
assert all(p.exists() for p in (SWIFT,PBX,APP,UI,WORKER)), 'Faltan fuentes'
service=SWIFT.read_text()
project=PBX.read_text()
app=APP.read_text()
ui=UI.read_text()
assert 'NXOwnedResourceUpdater.swift in Sources' in project
assert '3105U200,' in project
assert '.environmentObject(ownedUpdater)' in ui
assert 'ownedUpdater.checkWhenActive()' in ui
assert 'ACTUALIZACIONES DE NEXORA' in ui
assert '$ownedUpdater.autoEnabled' in ui
assert 'SHA256.hash(data: bytes)' in service
assert 'candidate.host?.lowercased() == source.host?.lowercased()' in service
assert 'NexoraOwnedResources' in service
assert 'DevicePatchService' not in service and 'PatchTransaction' not in service
assert 'NXUpdateJournal' in service and 'recoverInterruptedTransactions' in service
assert 'installed.json' in service and 'digestMismatch' in service
assert 'file.lowercased() != "installed.json"' in service
assert 'if FileManager.default.fileExists(atPath: backup.path)' in service

if shutil.which('swiftc'):
    result = subprocess.run(['swiftc','-frontend','-parse',str(SWIFT),str(APP),str(UI)],capture_output=True,text=True)
    assert result.returncode == 0, result.stderr

if shutil.which('node'):
    with tempfile.TemporaryDirectory() as d:
        runner=Path(d)/'test.mjs'
        runner.write_text('''
import {pathToFileURL} from 'node:url';
const worker=(await import(pathToFileURL(process.argv[2]).href)).default;
const root='https://nexora-updates.example.workers.dev';
const response=await worker.fetch(new Request(root+'/manifest.json'));
if (response.status!==200) throw new Error('HTTP manifest');
const manifest=await response.json();
if(manifest.schema!==1||manifest.resources.length!==1) throw new Error('Invalid catalog');
const r=manifest.resources[0];
const content=await worker.fetch(new Request(root+r.url));
if(content.status!==200)throw new Error('HTTP resource');
const bytes=await content.arrayBuffer();
const hex=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(b=>b.toString(16).padStart(2,'0')).join('');
if(hex!==r.sha256||bytes.byteLength!==r.bytes)throw new Error('Integrity mismatch');
const missing=await worker.fetch(new Request(root+'/notfound'));
if(missing.status!==404)throw new Error('Unknown path accepted');
console.log('Worker: manifiesto + descarga + SHA-256 OK');
''')
        result=subprocess.run(['node',str(runner),str(WORKER)],capture_output=True,text=True)
        assert result.returncode == 0,result.stderr
        print(result.stdout.strip())
print('Build 13: comprobaciones de estructura, aislamiento y catálogo OK')
