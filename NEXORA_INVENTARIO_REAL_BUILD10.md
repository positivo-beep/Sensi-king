# NEXORA SYSTEM 2026 — Inventario de recursos Build 10

**Base:** Build 10 (rama conservadora que deriva de fuentes anteriores). No se reemplazó el motor con código Build 18.

## Cifras comprobadas

- Fuentes recuperadas de la versión anterior: **197 archivos**.
- Rutas originales que están presentes en este paquete: **197 de 197**.
- Archivos originales cuyos contenidos son idénticos: **190**.
- Archivos originales modificados respecto de la fuente recuperada: **7**, listados debajo.
- Recurso externo de Rainbow Color Rojo: incorporado además en `BundledMods/HOLOGRAMA/Rainbow Color Rojo/`. Su SHA-256 coincide exactamente con la copia presente en `Assets.xcassets`.
- El paquete mantiene las fuentes Swift, proyecto Xcode, iconos, sonidos, recursos, licencias, herramientas de prueba y flujo GitHub Actions.

## Por qué pesa menos que Build 18

Build 18 incluye una segunda copia del proyecto dentro de `ThreeOneOSFive/`, varias carpetas repetidas y un ZIP histórico de alrededor de 14 MB. Esos duplicados no son necesarios para compilar el proyecto principal; importarlos puede causar conflictos de versiones. Aquí se conserva la estructura única de Build 10.

## Archivos anteriores cambiados legítimamente en Build 10

- `.github/workflows/build-nexora-ios.yml`
- `NEXORA_V14_MAPA_DE_OPCIONES.json`
- `ThreeOneOSFive.xcodeproj/project.pbxproj`
- `ThreeOneOSFive/ContentView.swift`
- `ThreeOneOSFive/helpers/LimitedCleanerService.swift`
- `ThreeOneOSFive/helpers/NXOwnedTemporaryWorkspaces.swift`
- `scripts/PruebaTemporalesNX.swift`


## Verificación y límites

- Se ejecutan comprobaciones Python y un análisis sintáctico de archivos Swift (sin disponer de Xcode).
- El código Swift específico de iOS debe compilarse y probarse en un entorno Apple compatible; no se ha probado en el iPhone.
- Las comprobaciones de archivos locales no demuestran acceso autorizado a los datos privados de otras aplicaciones.
- Esta entrega **no garantiza** ausencia de errores en ejecución ni traslada automáticamente todas las modificaciones internas de Build 18, porque algunas introdujeron fallos.
- Mantener copia intacta de la IPA funcional previa y evitar instalar encima antes de una prueba separada.

## Catálogo de opciones revisado

- **13 opciones** contienen un recurso y aparecen como `incluido` en el catálogo. Esto confirma presencia de recursos, no su activación en iPhone.
- **8 opciones** están marcadas como `pendiente` porque no contienen un archivo aportado: BALAS MÁGICAS, AIM CABEZA ANTENA, TEXTURA PERSONALIZADA, WALK HACK, HOLO ARM PERSONALIZADO 2, HOLOGRAMA PERSONAJE VERDE, TEXTURA CLARA, TEXTURA OSCURA. **No se inventaron archivos** para estas opciones.
