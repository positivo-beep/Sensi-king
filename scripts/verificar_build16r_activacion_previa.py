#!/usr/bin/env python3
"""Prueba funcional del preflight Foundation; NO garantiza acceso iOS ni compatibilidad Unity."""
from pathlib import Path
import subprocess,json,hashlib,tempfile,re
root=Path(__file__).resolve().parents[1]
source=root/'ThreeOneOSFive/helpers/NXActivationPreflight.swift'
ui=(root/'ThreeOneOSFive/ContentView.swift').read_text()
pbx=(root/'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
assert 'try NXActivationPreflight.validateBundledResource(payload)' in ui
assert 'try NXActivationPreflight.validateReadableWritableOriginal(at: target)' in ui
assert pbx.count('3105W201')==2 and pbx.count('3105W101')==3
assets=root/'ThreeOneOSFive/Assets.xcassets'
datas=sorted(assets.glob('NXMod*.dataset'))
assert len(datas)>=13
# Solo los 15 recursos activos en catálogo, sin incluir extras.
used=set(re.findall(r'dataAsset: "(NXMod[^" ]+)"',ui))
assert len(used)==15,len(used)
paths=[]
for name in sorted(used):
 directory=assets/(name+'.dataset')
 meta=json.loads((directory/'Contents.json').read_text())
 paths.append(str(directory/meta['data'][0]['filename']))
with tempfile.TemporaryDirectory(prefix='nx-preflight-') as td:
 executable=Path(td)/'run'
 proc=subprocess.run(['swiftc',str(source),str(root/'scripts/PruebaPrevencionActivacionNX.swift'),'-o',str(executable)],capture_output=True,text=True)
 assert proc.returncode==0,proc.stderr
 proc=subprocess.run([str(executable),*paths],capture_output=True,text=True)
 assert proc.returncode==0,proc.stdout+proc.stderr
 print(proc.stdout.strip())
print('OK: Build 16R, preflight registrado en Xcode; no se modificó el motor de transacción.')
