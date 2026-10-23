#!/usr/bin/env python3
"""Inspección de la nueva variante HOLO PJ; no sustituye la prueba funcional en iPhone."""
from pathlib import Path
import hashlib,json,struct,lzma
R=Path(__file__).resolve().parents[1]
def lz4_decode(block: bytes, expected: int) -> bytes:
    """Decodifica un bloque LZ4 puro (sin bibliotecas externas en GitHub Actions)."""
    out=bytearray();i=0
    while i<len(block):
        token=block[i];i+=1
        literal=token>>4
        if literal==15:
            while True:
                assert i<len(block)
                extension=block[i];i+=1;literal+=extension
                if extension!=255:break
        assert i+literal<=len(block)
        out.extend(block[i:i+literal]);i+=literal
        assert len(out)<=expected
        if i==len(block):break
        assert i+2<=len(block)
        back=int.from_bytes(block[i:i+2], 'little');i+=2
        assert 0<back<=len(out)
        n=(token&15)+4
        if (token&15)==15:
            while True:
                assert i<len(block)
                ext=block[i];i+=1;n+=ext
                if ext!=255:break
        assert len(out)+n<=expected
        for _ in range(n):out.append(out[-back])
    assert len(out)==expected
    return bytes(out)

name='HOLOGRAMA PERSONA OSCURO RAINBOW OSCURO'
asset='NXModHoloPjOscuroRainbowOscuro'
filename='optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D'
sha='22fd920de462bda852649a604cac2116df84eeb9a9955197dcb37d8bd3c115a1'
target='Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles/optionalavatarres_commonab_shader.BNrjwQsbTrqz6jACY9i6FB6DyYI~3D'
b= (R/'ThreeOneOSFive/Assets.xcassets'/f'{asset}.dataset'/filename).read_bytes()
original=(R/'BundledMods/HOLO PERSONAJE/Holograma Persona Oscuro Rainbow Oscuro'/filename).read_bytes()
assert b==original
assert hashlib.sha256(b).hexdigest()==sha
assert len(b)==381140 and b.startswith(b'UnityFS\0')
asset_dir=R/'ThreeOneOSFive/Assets.xcassets'/f'{asset}.dataset'
assert json.loads((asset_dir/'Contents.json').read_text())['data'][0]['filename']==filename
catalog=json.loads((R/'NEXORA_V14_MAPA_DE_OPCIONES.json').read_text())
found=[x for x in catalog if x['opcion']==name]
assert len(found)==1
item=found[0]
assert (item['categoria'],item['recurso'],item['estado'],item['destino_relativo'],item['sha256'],item['tamano_bytes'])==('HOLO PJ',asset,'incluido',target,sha,len(b))
ui=(R/'ThreeOneOSFive/ContentView.swift').read_text()
assert ui.count('title: "'+name+'"')==1
assert ui.count('dataAsset: "'+asset+'"')==1
assert ui.count('targetPath: "'+target+'"')==4
assert 'let finalHologram = builtIn.first(where: { $0.dataAsset == "'+asset+'" })' in ui
assert 'builtInPatchRow(finalHologram)' in ui
# UnityFS: declared archive may be shorter than padded on-disk file;
# block metadata is LZ4, archive data compressed with LZMA.
version=int.from_bytes(b[8:12],'big');assert 6<=version<=8
pos=12
for _ in range(2):pos=b.index(b'\0',pos)+1
size,cs,raw,flags=struct.unpack_from('>QIII',b,pos)
assert size<=len(b) and size>64 and 0<cs<size and raw>0 and flags&0x3f==3
meta=lz4_decode(b[size-cs:size],raw)
assert len(meta)==raw
cnt=struct.unpack_from('>I',meta,16)[0];assert 1<=cnt<=16
block_pos=(pos+20+15)&~15
at=20;expanded=0
for _ in range(cnt):
    expected,packed,codec=struct.unpack_from('>IIH',meta,at);at+=10
    assert expected>0 and packed>5 and block_pos+packed<=size-cs
    block=b[block_pos:block_pos+packed]
    if codec&0x3f==1:
        prop=block[0]
        data=lzma.LZMADecompressor(format=lzma.FORMAT_RAW,filters=[dict(id=lzma.FILTER_LZMA1,dict_size=int.from_bytes(block[1:5],'little'),lc=prop%9,lp=prop//9%5,pb=prop//45)]).decompress(block[5:])
    elif codec&0x3f==3:
        data=lz4_decode(block,expected)
    else:
        raise AssertionError('codec no verificado: '+str(codec&0x3f))
    assert len(data)==expected
    expanded+=len(data);block_pos+=packed
assert block_pos==size-cs and expanded>0
# Preserve the transaction and kernel paths (no changes to the underlying engine).
for path, hash in json.loads((R/'NEXORA_BUILD16_CAMBIOS_SHA256.json').read_text()).items():
    if path=='ThreeOneOSFive/ContentView.swift':continue
    assert hashlib.sha256((R/path).read_bytes()).hexdigest()==hash,path
print('OK: holograma oscuro Rainbow — datos UnityFS completos, botón final, opciones previas intactas, SHA-256 verificado.')
