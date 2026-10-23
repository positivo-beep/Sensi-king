from pathlib import Path
import json, plistlib, xml.etree.ElementTree as ET
root = Path(__file__).resolve().parent.parent
proj = (root / 'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
# Los archivos de prueba en subcarpetas scripts/ o tests/ NO pertenecen
# al target de la app de iOS. No deben exigirse en PBXSourcesBuildPhase.
# Comprobar exactamente los archivos de la fase Sources de Xcode.
# Un .swift extra (p. ej. de una versión antigua del repositorio) NO demuestra
# por sí mismo que la app esté incompleta y no debe bloquear todo el build.
import re

def section(begin, end):
    assert begin in proj and end in proj, f'Falta sección Xcode: {begin}'
    return proj.split(begin, 1)[1].split(end, 1)[0]

build_section = section('/* Begin PBXBuildFile section */', '/* End PBXBuildFile section */')
file_section = section('/* Begin PBXFileReference section */', '/* End PBXFileReference section */')
group_section = section('/* Begin PBXGroup section */', '/* End PBXGroup section */')
phase_section = section('/* Begin PBXSourcesBuildPhase section */', '/* End PBXSourcesBuildPhase section */')

# PBXBuildFile (ID) -> PBXFileReference (ID).
build_refs = dict(re.findall(
    r'(?m)^\s*([A-Za-z0-9]+) /\* .*? in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-Za-z0-9]+); \};',
    build_section,
))
assert build_refs, 'No hay archivos de compilación en Xcode'

# ID del archivo -> ruta relativa declarada por Xcode.
file_refs = {}
for m in re.finditer(r'(?m)^\s*([A-Za-z0-9]+) /\* .*? \*/ = \{isa = PBXFileReference; (.*?)\};', file_section):
    path = re.search(r'\bpath = (?:"([^"]+)"|([^;]+));', m.group(2))
    if path:
        file_refs[m.group(1)] = (path.group(1) or path.group(2)).strip()

# Resolver PBXGroup.path según la jerarquía, no solo por nombre de archivo.
parents = {}
group_paths = {}
for m in re.finditer(r'(?m)^\s*([A-Za-z0-9]+)(?: /\* .*? \*/)? = \{\s*isa = PBXGroup;\s*children = \((.*?)\);(.*?)\};', group_section, re.S):
    gid, children, props = m.groups()
    p = re.search(r'\bpath = (?:"([^"]+)"|([^;]+));', props)
    group_paths[gid] = (p.group(1) or p.group(2)).strip() if p else ''
    for child in re.findall(r'(?m)^\s*([A-Za-z0-9]+) /\*', children):
        assert child not in parents, f'Referencia Xcode en más de un grupo: {child}'
        parents[child] = gid

def xcode_path(ref):
    assert ref in file_refs, f'Falta PBXFileReference: {ref}'
    pieces = [file_refs[ref]]
    parent = parents.get(ref)
    seen = set()
    while parent:
        assert parent not in seen, 'Ciclo en PBXGroup'
        seen.add(parent)
        if group_paths.get(parent):
            pieces.insert(0, group_paths[parent])
        parent = parents.get(parent)
    return root.joinpath(*pieces)

# Verificar la fase Sources real (no todos los .swift presentes en el disco).
source_phases = re.findall(r'\bisa = PBXSourcesBuildPhase;.*?\bfiles = \((.*?)\);', phase_section, re.S)
assert source_phases, 'No existe la fase Sources en el proyecto Xcode'
phase_ids = [bid.strip() for phase in source_phases for bid in phase.split(',') if bid.strip()]
assert phase_ids, 'La fase Sources de Xcode está vacía'
compiled = []
for bid in phase_ids:
    assert bid in build_refs, f'PBXBuildFile inexistente en Sources: {bid}'
    f = xcode_path(build_refs[bid])
    assert f.is_file(), f'Falta fuente referenciada por Xcode: {f.relative_to(root)}'
    compiled.append(f)

compiled_swift = {p.resolve() for p in compiled if p.suffix == '.swift'}
assert compiled_swift, 'No hay Swift en la fase Sources de Xcode'
for must_have in ('App.swift', 'ContentView.swift'):
    assert any(p.name == must_have for p in compiled_swift), f'{must_have} no está en Sources'

source_root = root / 'ThreeOneOSFive'
extra_swift = [p for p in source_root.rglob('*.swift') if p.resolve() not in compiled_swift]
if extra_swift:
    print(f'NOTA: {len(extra_swift)} archivo(s) Swift fuera del target; no se compilarán.')
    print('  Ejemplos: ' + ', '.join(str(p.relative_to(root)) for p in extra_swift[:5]))
files = list(compiled_swift)
for data in (root / 'ThreeOneOSFive/Assets.xcassets').rglob('Contents.json'):
    obj = json.loads(data.read_text())
    for entry in obj.get('images', []) + obj.get('data', []):
        if entry.get('filename'):
            assert (data.parent / entry['filename']).is_file(), f'Falta recurso: {entry["filename"]}'
info = plistlib.loads((root / 'ThreeOneOSFive/Info.plist').read_bytes())
assert info['CFBundleDisplayName'] == 'NEXORA SYSTEM 2026'
app = (root/'ThreeOneOSFive/App.swift').read_text()
assert 'hypersex-licencias-propias.nexora-system26.workers.dev' in app
assert '/v1/validate' in app and '/v1/activate' in app
panel = (root/'ThreeOneOSFive/ContentView.swift').read_text()
assert 'DevicePatchService.apply(' in panel and 'DevicePatchService.restore(' in panel
ET.parse(root/'ThreeOneOSFive.xcodeproj/xcshareddata/xcschemes/NEXORA_SYSTEM_2026.xcscheme')
print(f'PREVERIFICACION OK: {len(files)} fuentes Swift en Xcode, {len(compiled)} fuentes totales, assets, esquema, licencia y motor.')
