#!/usr/bin/env python3
"""Verifica que TEXTURA ALOK sea la única sustitución de TEXTURA PERSONALIZADA.
No garantiza que el destino exista o sea accesible en el iPhone.
"""
from pathlib import Path
import hashlib, json, struct, lzma
R=Path(__file__).resolve().parents[1]
ui=(R/'ThreeOneOSFive/ContentView.swift').read_text(encoding='utf8')
manifest=json.loads((R/'NEXORA_ALOK_CAMBIOS_SHA256.json').read_text())
for name,sha in manifest.items():
    assert hashlib.sha256((R/name).read_bytes()).hexdigest()==(json.loads((R/'NEXORA_INVENTARIO_SHA256.json').read_text())[name] if name=='ThreeOneOSFive/ContentView.swift' else sha),name
assets=R/'ThreeOneOSFive/Assets.xcassets'
items=json.loads((R/'NEXORA_V14_MAPA_DE_OPCIONES.json').read_text())
options=[it for it in items if it['opcion']=='TEXTURA ALOK']
assert len(options)==1
it=options[0]
assert it['categoria']=='TEXTURA' and it['estado']=='incluido'
assert it['recurso']=='NXModTexturaAlok'
assert 'TEXTURA PERSONALIZADA' not in ui
assert not any(it2['opcion']=='TEXTURA PERSONALIZADA' for it2 in items)
assert ui.count('title: "TEXTURA ALOK"')==1
assert '"TEXTURA": ["TEXTURA CLARA", "TEXTURA OSCURA"]' in ui
folder=assets/(it['recurso']+'.dataset')
metadata=json.loads((folder/'Contents.json').read_text())
assert len(metadata['data'])==1
f=folder/metadata['data'][0]['filename']
b=f.read_bytes()
assert hashlib.sha256(b).hexdigest()==it['sha256']
assert len(b)==it['tamano_bytes']
assert b.startswith(b'UnityFS\0')
idx=12
assert 6<=int.from_bytes(b[8:12],'big')<=8
for _ in range(2):
    idx=b.index(b'\0',idx)+1
assert int.from_bytes(b[idx:idx+8],'big')==len(b)
# Inspeccionar metadatos al final y comprobar descompresión completa UnityFS.
block_meta_size=int.from_bytes(b[idx+8:idx+12], 'big')
block_meta_raw=int.from_bytes(b[idx+12:idx+16], 'big')
block_flags=int.from_bytes(b[idx+16:idx+20], 'big')
assert block_meta_size==block_meta_raw and 0 < block_meta_size < len(b)
assert block_flags & 0x80  # directorio de bloques al final
block_meta=b[-block_meta_size:]
pos=16
count=int.from_bytes(block_meta[pos:pos+4],'big'); pos+=4
assert 1 <= count <= 16
block_start=(idx+20+15)&~15
all_bytes=0
for _ in range(count):
    expected,packed,compression=struct.unpack_from('>IIH',block_meta,pos);pos+=10
    raw=b[block_start:block_start+packed]
    assert len(raw)==packed and packed>5
    assert compression&0x3f==1, 'Compresión LZMA no reconocida'
    prop=raw[0]
    decompressor=lzma.LZMADecompressor(format=lzma.FORMAT_RAW,filters=[{
        'id':lzma.FILTER_LZMA1,'dict_size':int.from_bytes(raw[1:5],'little'),
        'lc':prop%9,'lp':prop//9%5,'pb':prop//45
    }])
    result=decompressor.decompress(raw[5:])
    assert len(result)==expected
    all_bytes+=len(result)
    block_start+=packed
assert all_bytes>len(b)
assert f.name in it['destino_relativo']
assert ui.count('dataAsset: "NXModTexturaAlok"')==1
assert ui.count('targetPath: "'+it['destino_relativo']+'"')==1
assert 'try NXActivationPreflight.validateBundledResource(payload)' in ui
assert 'try NXActivationPreflight.validateReadableWritableOriginal(at: target)' in ui
assert 'DevicePatchService.restore(' in ui
assert len(items)==22
assert sum(x['estado']=='incluido' for x in items)==15
print('OK: TEXTURA ALOK importada íntegra, antigua fila sustituida, preflight y restauración conservados. Acceso iOS pendiente.')
