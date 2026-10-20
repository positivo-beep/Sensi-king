#!/usr/bin/env python3
"""Verifica la IPA real, no sólo un ZIP o el resultado verde de tests."""
import sys, plistlib, zipfile, hashlib, json, os, pathlib
ipa=pathlib.Path(sys.argv[1])
assert ipa.is_file() and ipa.stat().st_size>100_000, 'IPA ausente o demasiado pequeña'
with zipfile.ZipFile(ipa,'r') as z:
    assert z.testzip() is None, 'IPA dañada'
    names=set(z.namelist())
    prefix='Payload/3105.app/'
    assert prefix+'Info.plist' in names, 'No existe la aplicación esperada en IPA'
    assert prefix+'Assets.car' in names, 'Assets.car no se empaquetó'
    assert z.getinfo(prefix+'Assets.car').file_size>10_000, 'Catálogo de iconos/recursos vacío'
    plist=plistlib.loads(z.read(prefix+'Info.plist'))
    assert plist.get('CFBundleDisplayName')=='NEXORA SYSTEM 2026', 'Nombre incorrecto'
    assert plist.get('CFBundleIdentifier')=='com.nexora.system2026', \
        'Identificador incorrecto: revisar Info.plist y PRODUCT_BUNDLE_IDENTIFIER, no editar la IPA a mano'
    assert plist.get('CFBundleShortVersionString')=='2.1.9', 'La IPA NO es la versión nueva 2.1.9'
    assert str(plist.get('CFBundleVersion'))=='18', 'La IPA NO es el build 18'
    icons=plist.get('CFBundleIcons',{})
    primary=icons.get('CFBundlePrimaryIcon',{})
    assert ('AppIcon' in str(primary)), 'AppIcon no se registró en Info.plist'
    execname=plist.get('CFBundleExecutable','3105')
    assert prefix+execname in names, 'Ejecutable de iOS ausente'
    assert z.getinfo(prefix+execname).file_size>100_000, 'Ejecutable vacío'
    with z.open(prefix+execname) as executable:
        signature = executable.read(4)
    assert signature in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
                         b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'), \
        'No se encontró una cabecera Mach-O reconocida'
    report={
      'estado':'COMPILADA_Y_EMPAQUETADA; NO VALIDADA EN IPHONE',
      'git_sha':os.getenv('GITHUB_SHA','no_disponible'),
      'github_run_id':os.getenv('GITHUB_RUN_ID','no_disponible'),
      'ipa_archivo':ipa.name,
      'ipa_bytes':ipa.stat().st_size,
      'ipa_sha256':hashlib.sha256(ipa.read_bytes()).hexdigest(),
      'nombre_app':plist['CFBundleDisplayName'],
      'bundle_id':plist.get('CFBundleIdentifier','no_disponible'),
      'app_version':plist.get('CFBundleShortVersionString','no_disponible'),
      'build_number':str(plist.get('CFBundleVersion','no_disponible')),
      'icono_registrado':primary,
      'assets_car_bytes':z.getinfo(prefix+'Assets.car').file_size,
      'recurso_externo_verificado':False,
      'funciones_ios_verificadas':False,
    }
    output=ipa.parent/'NEXORA_RESULTADO_COMPILACION.json'
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('IPA VERIFICADA: ejecutable + Assets.car + icono + Info.plist. No se certifican funciones iPhone.')
    print('SHA256:',report['ipa_sha256'])
