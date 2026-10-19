## NEXORA V21.6 — RAINBOW COLOR ROJO

- Nuevo holograma de arma: RAINBOW COLOR ROJO (anteriormente HOLO ARM PERSONALIZADO 1, pendiente).
- Recurso extraído y verificado del paquete aportado `FREE HOLO SHADER.3105`, sin incorporar ni guardar su contraseña.
- Se mantienen el holograma Rainbow anterior, Azul con Verde y las variantes de personaje.
- Los tres hologramas de arma comparten el mismo destino y no deben activarse simultáneamente; se conserva el control existente de conflictos, respaldo y restauración.
- Esta integración se verifica estáticamente y no demuestra permisos sobre datos de otras apps ni compatibilidad visual en iPhone.

## NEXORA 2026 V21.6 — Conservación de archivos que cambiaron después de activar una opción

- Si un archivo modificado por NEXORA fue reemplazado externamente mientras la opción estaba activa, se conserva ese contenido en vez de sobrescribirlo con una copia antigua.
- Los archivos que siguen modificados por NEXORA sí vuelven a sus originales respaldados.
- Si un archivo desaparece, se interrumpe la restauración para evitar daños.
- Se conserva la advertencia de integridad para la próxima activación; los cambios externos no se confirman como oficiales sin una fuente confiable.
- Conserva audio personalizado, limpieza propia, Cloudflare, Discord y WhatsApp.
- No incluye ocultación de cambios ni eliminación de registros de seguridad.

## V21.5 — Avisos de versión del original
- Inspección del tamaño y SHA-256 del original antes de activar una opción, comparándolos con respaldos válidos anteriores.
- Al detectar un cambio, se bloquea la activación hasta confirmar de forma explícita que se revisó el archivo actual.
- Tras confirmar, se respalda el archivo actual para permitir una restauración coherente, sin reutilizar silenciosamente copias antiguas.
- Si el archivo desapareció, se cancela la operación.
- Conserva la advertencia de restauración cuando se modifica el destino durante una activación.
- Ninguna garantía de actualización oficial automática ni de eliminación de rastros externos.

## NEXORA V21.4 (2026-10-15) — Limpieza propia reforzada

- Recuperación en segundo plano al arrancar de espacios temporales NEXORA abandonados durante 48 horas o más, aislados de respaldos y otras apps.
- Limpieza de espacio temporal propio cuando falla la activación, sin alterar el error original.
- Nuevas pruebas reales: temporales recientes, limpieza repetida y enlaces simbólicos.
- Se conservan audio personalizado V21.2, restauración verificada V21.1, opciones V19 y licencia Cloudflare V20.
- **No** contiene funciones para ocultar modificaciones ni borrar registros de seguridad.

## NEXORA V21.3 — limpieza comprobable de temporales propios

- Nuevo `NXOwnedTemporaryWorkspaces.swift`: cada opción tiene un área temporal aislada por UUID dentro de Caches de la propia IPA.
- Las operaciones de limpieza se limitan a las carpetas creadas por NEXORA; no alcanzan registros, backups de transacciones ni archivos de otras apps.
- Nueva prueba accesible en Configuración > Diagnóstico técnico: comprueba dos opciones, limpia A sin afectar B y después limpia B, verificando que ambas carpetas desaparecen.
- La compilación de GitHub ejecuta la prueba real en Swift antes de generar la IPA.
- No se implementan ni se prometen funciones de ocultación de cambios o supresión de registros de seguridad.

## V21.1 — Comprobación real de restauración (2026-10-15)
- Verificación SHA-256 de todos los archivos recuperados antes de declarar la restauración exitosa.
- Comprobación de ausencia de archivos creados por una opción desactivada.
- Ante discrepancia, error explícito y recuperación del estado previo cuando sea posible.
- Mantiene el sonido de activación de V21.

# Changelog

All notable user-facing changes are documented in this file.

## [2.1.3 build 12] - 2026-10-19 — Mejoras de fiabilidad

- Limpieza de temporales propios más conservadora: nombres seguros, rechazo de entradas anómalas y pruebas de conservación.
- Reemplazo de archivos con comprobación de cambios durante la copia y verificación del staging.
- Limpiador limitado de caché con suma segura y profundidad acotada.
- Pruebas funcionales nuevas para ejecutar en GitHub Actions/macOS.
- Artefactos y verificadores de versión sincronizados para evitar confusión con builds anteriores.
- **Pendiente:** compilación en Xcode e instalación/validación real en iPhone. Cloudflare sin cambios.

## [1.0.1] - 2026-08-15

### Added

- Bundle-tree Patch workspace v2 under `On My iPhone/3105/Patches`, synchronized automatically when applying or exporting.
- Multiple independent Files tabs with preserved navigation state.
- ZIP extraction with path, symbolic-link, CRC, and available-space validation.
- Responsive iPad split-view and landscape navigation.
- Home toggles for showing or hiding Cleaner and Wallpaper features.

### Changed

- Patch creation from an app-container file or folder now captures the stable bundle identifier and editable destination tree automatically.
- Patch package imports no longer use the previous fixed payload-size or file-count ceiling; practical device storage and memory still apply.
- Files and Patch screens now use consistent grouped cards, compact icons, balanced nested rows, and stable search presentation.
- Legacy v1 `.3105` packages remain importable and usable.

### Fixed

- Patch Restore now restores files that existed before Apply, removes files introduced by the patch, and removes patch-created folders after they become empty.
- File navigation remains at the current folder when switching app sections and restores the correct folder independently for each Files tab.
- Empty Patch and Cleaner actions now share the same visual treatment.
- Corrected PosterBoard wallpaper activation guidance and the iOS 27 Collections prerequisite.
- Refined navigation icon rendering and nested file-row spacing.

### Compatibility

- Verified iOS 26.0–26.6.1.
- Verified iOS 27 Developer Beta 1–4, including Public Beta 1–2 mappings listed in the app.
- Added iPhone and iPad interface support; device-level features still require enterprise signing.

## [1.0 beta 3] - 2026-08-14

### Added

- Bundle-based App Data Browser with MHA-C2 container discovery.
- Native file operations: search, multi-file import, rename, delete, create file/folder, and conflict handling.
- Portable `.3105` patch projects with optional password protection and file/folder rules.
- Limited per-app cleaner for `Library/Caches` and `tmp`.
- Wallpaper Lab for validated `.tendies` packages with installation receipts and targeted reset.
- English, Vietnamese, and Simplified Chinese localization.

### Changed

- Simplified the app into a five-tab, native SwiftUI layout inspired by focused iOS container tools.
- Moved the enterprise-signing notice below device information on Home.
- Refined the orange accent, empty states, actions, and navigation presentation.

### Fixed

- Stabilized persistent search presentation in app and file browsers.
- Fixed native document selection for replacement files and `.3105` package imports.
- Resolved bundle-name mapping for enumerated app containers where metadata is available.
- Limited wallpaper reset to active content installed by 3105.
- Corrected Cleaner layout when no removable app data is found.

### Compatibility

- Verified iOS 26.0–26.6.1.
- Verified iOS 27 beta 1–4 builds listed in the app.
- Unlisted iOS 27 builds remain disabled until explicitly verified.
