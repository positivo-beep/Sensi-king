# NEXORA SYSTEM 2026 — Build 13: actualización de recursos propios

Esta entrega parte del proyecto que el usuario confirmó como funcional: **Build 12, interfaz roja y logotipo rojo**.

## Qué se añadió

- En **Configuración → ACTUALIZACIONES DE NEXORA**: URL HTTPS, interruptor de búsqueda automática al abrir la aplicación y botón de búsqueda manual.
- Cada vez que la app vuelve a estar activa se comprueba el catálogo si hay una URL configurada, la opción está activada y transcurrieron al menos 12 horas desde la última revisión satisfactoria.
- Catálogo JSON v1, versiones enteras y descarga de **recursos propios** de NEXORA con verificación SHA-256 y tamaño exacto.
- Cada recurso se guarda solamente en **Application Support/NexoraOwnedResources**. Se crea respaldo del archivo reemplazado, recibo de instalación y diario para recuperación tras interrupciones.
- Solo `https`, sin redirecciones, y recursos en el mismo host del catálogo; no se envían claves de licencia en las descargas.
- Extensiones limitadas: json, txt, png, jpg, jpeg, webp y dat. No ejecutables, scripts, IPAs, perfiles, rutas externas ni `installed.json`.
- Incluye un Worker de Cloudflare **independiente** de ejemplo con un catálogo real y un recurso de notas; no reemplaza el Worker de claves.

## Para ponerlo en funcionamiento completo

1. Crea un **Worker nuevo** en Cloudflare, diferente del Worker de licencias.
2. Copia `deploy/nexora-updates-worker.mjs` como código de ese Worker y despliégalo. El ejemplo no requiere cuentas ni almacenamiento R2.
3. Comprueba en Safari/Chrome que `https://TU-WORKER.workers.dev/manifest.json` devuelva JSON con `schema: 1`.
4. Compila Build 13 en **una rama de prueba** y abre **Configuración → ACTUALIZACIONES DE NEXORA**.
5. Pega la URL HTTPS del catálogo, activa **Buscar automáticamente al abrir** y pulsa **Buscar actualizaciones ahora**.
6. Debes ver `1 recurso(s) de NEXORA actualizado(s) y verificado(s).` y el texto de las notas en Configuración.
7. Para demostrar una actualización nueva, aumenta `REVISION` y cambia `NOTES` en el Worker; vuelve a desplegar y a pulsar Buscar.

Sin publicar el Worker y configurar la URL no existe un servidor remoto del que descargar versiones nuevas; en ese caso el sistema permanecerá **sin configurar**, sin inventar actualizaciones.

## Límites y seguridad

- **No es un actualizador del binario `.ipa`**. iOS requiere instalar nuevas versiones de la app por una vía de distribución autorizada.
- **No actualiza ni modifica archivos privados de Free Fire ni de otras apps.** El motor de activación y los archivos externos permanecen intactos.
- Las sumas SHA-256 permiten detectar corrupciones o cambios respecto al catálogo, pero si el servidor del catálogo está comprometido el atacante podría modificar tanto el archivo como el hash. Usa una cuenta segura para administrar el Worker.
- Las pruebas locales incluidas no equivalen a una compilación de Xcode, ni demuestran que el Worker real o la red de tu iPhone funcionen. Ejecuta GitHub Actions y haz la prueba en iPhone antes de llamar estable a la versión.
- Conserva tu Build 12 funcional durante todas las pruebas.

## Ficheros principales

- `ThreeOneOSFive/helpers/NXOwnedResourceUpdater.swift` — motor de recursos propios
- `ThreeOneOSFive/ContentView.swift` — controles en Configuración y comprobación al primer plano
- `ThreeOneOSFive.xcodeproj/project.pbxproj` — inclusión del nuevo archivo Swift en la compilación
- `deploy/nexora-updates-worker.mjs` — servidor de ejemplo
- `scripts/verificar_nexora_autoupdate.py` — verificaciones locales de aislamiento y catálogo

**No se alteraron:** `ThreeOneOSFive/App.swift`, `DevicePatchService.swift`, `PatchTransaction.swift`, `FileReplacementService.swift`, código de licencias ni recursos visuales.
