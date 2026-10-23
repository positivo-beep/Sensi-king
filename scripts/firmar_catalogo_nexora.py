#!/usr/bin/env python3
"""Firma/valida catálogos de ACTUALIZACIONES PROPIAS de NEXORA (Ed25519).

Requiere: pip install cryptography
Ejemplos:
  python scripts/firmar_catalogo_nexora.py generar --private FUERA_DEL_REPO/clave.pem --public FUERA_DEL_REPO/publica.txt
  python scripts/firmar_catalogo_nexora.py firmar --private FUERA_DEL_REPO/clave.pem --manifest catalogo.json --output catalogo-firmado.json
  python scripts/firmar_catalogo_nexora.py verificar --public FUERA_DEL_REPO/publica.txt --catalogo catalogo-firmado.json

NUNCA subas el archivo privado .pem a GitHub. Solo la clave PÚBLICA se pega en la app.
"""
import argparse
import base64
import json
from pathlib import Path
import sys
try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey, Ed25519PublicKey
    from cryptography.hazmat.primitives import serialization
except ImportError:
    raise SystemExit("Falta cryptography: instala con python -m pip install cryptography")

PROJECT = Path(__file__).resolve().parents[1]

def outside_repo(path):
    if Path(path).resolve().is_relative_to(PROJECT):
        raise ValueError("La clave PRIVADA debe estar FUERA del directorio del proyecto.")

def generate(private, public):
    outside_repo(private)
    priv=Ed25519PrivateKey.generate()
    data=priv.private_bytes(encoding=serialization.Encoding.PEM,
         format=serialization.PrivateFormat.PKCS8, encryption_algorithm=serialization.NoEncryption())
    dest=Path(private)
    with dest.open('xb') as f: f.write(data)
    try: dest.chmod(0o600)
    except OSError: pass
    pub=priv.public_key().public_bytes(encoding=serialization.Encoding.Raw,
         format=serialization.PublicFormat.Raw)
    Path(public).write_text(base64.b64encode(pub).decode('ascii')+'\n')
    print("Clave pública Base64 generada. Mantén el .pem privado FUERA de GitHub.")

def signing(private, manifest, output):
    outside_repo(private)
    raw=Path(manifest).read_bytes()
    parsed=json.loads(raw)
    if parsed.get('schema')!=1 or not isinstance(parsed.get('resources'),list):
        raise ValueError('Manifest de NEXORA no válido')
    priv=serialization.load_pem_private_key(Path(private).read_bytes(), password=None)
    if not isinstance(priv,Ed25519PrivateKey): raise ValueError('Se necesita clave privada Ed25519')
    sig=priv.sign(raw)
    envelope={'format':'nexora-ed25519-v1',
              'payloadBase64':base64.b64encode(raw).decode('ascii'),
              'signatureBase64':base64.b64encode(sig).decode('ascii')}
    Path(output).write_text(json.dumps(envelope,indent=2,ensure_ascii=False)+'\n')
    print('Catálogo firmado. Puedes publicar solo el JSON público, no la clave privada.')

def verify(public, catalog):
    pub=Ed25519PublicKey.from_public_bytes(base64.b64decode(Path(public).read_text().strip(),validate=True))
    e=json.loads(Path(catalog).read_text())
    if e.get('format')!='nexora-ed25519-v1': raise ValueError('Envoltura incorrecta')
    payload=base64.b64decode(e['payloadBase64'],validate=True)
    pub.verify(base64.b64decode(e['signatureBase64'],validate=True),payload)
    obj=json.loads(payload)
    if obj.get('schema')!=1 or not isinstance(obj.get('resources'),list): raise ValueError('Manifest inválido')
    print('Firma Ed25519 correcta para la clave pública suministrada.')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub=parser.add_subparsers(dest='cmd',required=True)
    g=sub.add_parser('generar'); g.add_argument('--private',required=True); g.add_argument('--public',required=True)
    s=sub.add_parser('firmar'); s.add_argument('--private',required=True); s.add_argument('--manifest',required=True); s.add_argument('--output',required=True)
    v=sub.add_parser('verificar'); v.add_argument('--public',required=True); v.add_argument('--catalogo',required=True)
    args=parser.parse_args()
    try:
        if args.cmd=='generar': generate(args.private,args.public)
        if args.cmd=='firmar': signing(args.private,args.manifest,args.output)
        if args.cmd=='verificar': verify(args.public,args.catalogo)
    except Exception as error:
        print(f'Error: {error}',file=sys.stderr)
        sys.exit(1)
