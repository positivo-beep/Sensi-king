# NEXORA SYSTEM 2026 — Build 14 (laboratorio de compatibilidad de versiones)

## Qué se añadió realmente

- Detecta cambios de **cualquier byte** con SHA-256 al consultar una pareja original/variante.
- Un catálogo HTTPS puede entregar una pareja **original vN + variante para ese original vN**, con SHA-256 y tamaño de ambos recursos.
- Rechaza variantes cuyo campo `modifiedForOriginalSHA256` no coincide con el hash del original.
- Verifica los dos ficheros descargados antes de publicarlos.
- Escribe los originales y variantes nuevos en una carpeta de versión inmutable; cambia el **índice** al final y en una única escritura atómica. La versión anterior se conserva para recuperación.
- Si falta la nueva variante, falla la descarga, no coincide SHA-256, cambia un byte del original local o falta espacio, **no utiliza la variante antigua**.
- Botones de prueba en Configuración: **Revisar versiones originales / Probar variante propia / Restaurar prueba**.
- La prueba reversible emplea un archivo de texto del sandbox de la propia NEXORA, nunca datos de terceros.

## Lo que NO hace

1. **No** convierte automáticamente un mod viejo para adaptarlo a una nueva versión. Para cada versión del original se necesita publicar una variante compatible y verificable.
2. **No** tiene acceso autorizado a archivos privados de Free Fire u otras aplicaciones. No hay conexión entre el actualizador del sandbox y el motor externo anterior.
3. **No** actualiza el ejecutable `.ipa` por sí solo.
4. El Worker incluido sirve una **pareja de ejemplo** (`nexora-demo`), no los recursos reales del juego. No contiene versiones de archivos del juego.
5. Los SHA-256 detectan alteración de bytes, **pero no prueban la autenticidad del publicador** si el catálogo y los hashes son modificados por un atacante.

## Probar los dos estados

1. Despliega el **Worker de prueba independiente** `deploy/nexora-updates-worker.mjs` (no sustituye al Worker de licencias).
2. Configura en NEXORA `https://<tu-worker>.workers.dev/manifest.json` desde **Configuración → Actualizaciones de NEXORA**.
3. Pulsa «Buscar actualizaciones ahora». Debe informar de una pareja original/variante compatible.
4. Pulsa «Probar variante propia» y «Restaurar prueba», ambos dentro del sandbox.
5. Para publicar otra versión, incrementa `REVISION` y ajusta **ambos archivos** del Worker. Tras desplegarlo, repite la búsqueda y la prueba.
6. Si el original tiene un solo byte distinto y la pareja del catálogo no corresponde, se bloquea la variante (no se fuerza ni se restaura automáticamente).

## Pruebas

- `python3 scripts/verificar_build14_compatibilidad_original.py`: comprueba referencias, sintaxis Swift, SHA-256 y servidor de prueba, incluyendo modificación de un solo byte.
- `python3 scripts/verificar_no_regresion_nexora.py`: garantiza que los archivos originales protegidos del motor anterior no han cambiado.
- El resto de scripts existentes permanece conectado al workflow de GitHub Actions.

**Resultado y límite:** las verificaciones locales no garantizan una compilación sin fallos ni el funcionamiento en iPhone. No reemplaces Build 12 funcional hasta terminar una prueba en una rama distinta. 
