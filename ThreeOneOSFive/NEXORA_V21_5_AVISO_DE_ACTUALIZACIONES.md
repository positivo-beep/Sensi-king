# NEXORA SYSTEM 2026 V21.5 — Avisos de integridad del archivo original

## Qué cambia

- Se comparan **tamaño y SHA-256** del archivo actual con el original conservado en el último respaldo válido de NEXORA, **antes** de aplicar un reemplazo.
- Se detectan cambios de contenido incluso cuando el archivo ocupa exactamente los mismos bytes.
- Si se detecta un cambio, la interfaz muestra un aviso y **cancela la activación** a menos que la persona usuaria confirme que revisó la versión actual y la compatibilidad del archivo modificado.
- Si se confirma, el motor crea un respaldo del **archivo actual**, no del original antiguo, para que al desactivar vuelva a ese contenido.
- Si el original previamente conocido **desapareció**, no se permite continuar como si existiera un nuevo original, aun después de la confirmación.
- Si el archivo cambia **durante** una activación, el sistema de restauración existente detecta esa diferencia y bloquea la restauración automática para no sobrescribir el nuevo contenido inadvertidamente.
- Se conservan el audio personalizado, la limpieza de temporales propios de NEXORA, WhatsApp, Discord y licencias Cloudflare. Ninguna clave o variable de Cloudflare se modifica.

## Limitaciones reales

- Un cambio de SHA-256 **no demuestra** que la modificación venga de una actualización oficial, por eso se solicita revisión antes de continuar.
- No se descargan originales actualizados automáticamente; eso requeriría un origen oficial confiable y un mecanismo de validación de versiones o firmas proporcionado por el titular de los archivos.
- Si una actualización externa aparece **mientras hay una opción activa**, NEXORA no puede distinguir automáticamente una actualización oficial de una modificación ajena: detiene la restauración automática y advierte. No sustituye automáticamente un respaldo antiguo por un archivo desconocido.
- La comparación histórica solo funciona cuando existe un **respaldo válido previo del mismo archivo y contenedor**. En el primer uso, NEXORA registra el original en el respaldo de la operación, pero no puede deducir una versión anterior desconocida.
- Esta es una protección de integridad y recuperación de datos, **no** un sistema de borrado de registros de seguridad ni de eliminación de todo rastro de cambios.
- Los archivos externos de aplicaciones pueden no estar accesibles en iOS; no se promete acceso universal a otros contenedores.

## Verificación

- Comprobación sintáctica de los archivos Swift con `swiftc -frontend -parse` (Linux, no equivale a compilación iOS).
- Los scripts de verificación y la prueba local de temporales de V21.4 se vuelven a ejecutar.
- Pendiente: compilación en GitHub Actions (Xcode/macOS) e inspección del aviso en iPhone con archivos de prueba propios.
