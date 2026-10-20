# NEXORA SYSTEM 2026 — Reemplazo, actualización y restauración v2.1.8 (build 17)

**Situación:** fuentes listas para realizar pruebas de compilación; **no se ha generado ni probado una IPA en iPhone**. No se modifica Cloudflare ni la instalación anterior.

## Motivo del cambio

GitHub Actions detuvo el workflow en `Pruebas de reemplazo seguro de archivos propios` por `FileReplacementError.sourceChangedDuringCopy` y código 133. No llegó a ejecutar el paso de compilación de iOS.

El motor de reemplazo ahora usa `lstat`/`fstat` para contrastar identidad, tamaño y las fechas de cambio del archivo original y el actualizado. Comprueba los archivos antes y después de copiar, rechaza enlaces simbólicos y copias incoherentes, conserva el destino cuando hay cambios externos y elimina el fichero temporal de preparación al fallar. El proceso se limita a rutas a las que la app tiene acceso legítimo.

## La actualización de archivos pedida

El motor `PatchTransaction` permite distinguir la versión previa usando SHA-256 del original. Cuando cambia el archivo original, impide instalar automáticamente la modificación antigua. Para actualizar, hay que aportar el archivo nuevo **compatible** y asociarlo al SHA-256 del original actual; antes de activarlo se hace respaldo verificable. Al desactivar se intenta restaurar ese original. Si el archivo cambia por fuera, se preserva y se notifica para revisión.

No existe forma segura de fabricar un archivo actualizado válido desde uno antiguo sin el contenido y los permisos correspondientes; tampoco se pueden superar por defecto las restricciones de iOS entre contenedores de distintas apps.

## Verificaciones locales

- **16/16** pruebas del reemplazo (Swift en Linux, incluidas actualización, archivo vacío, enlaces simbólicos, origen ausente, modificación concurrente del original/destino y limpieza de temporales).
- Limpieza de temporales propios: pruebas funcionales locales.
- Scripts de verificación estática, manifiesto de integridad y metadatos de release sincronizados con la versión 2.1.8/build17.
- GitHub Actions conserva logs del reemplazo seguro, limpieza y pruebas antes de generar la IPA.
- Falta que GitHub macOS ejecute los mismos tests y que `xcodebuild` genere la IPA. Un test verde no implica que se puedan escribir los archivos de otras apps en iOS.

## Uso

Copiar el contenido del ZIP en la raíz del repositorio correspondiente (incluida la carpeta oculta `.github`), después ejecutar Actions → build. Se guardan reportes siempre que el runner alcance el paso de artefactos. No instalar ni firmar nada hasta que el build termine y la IPA se inspeccione.
