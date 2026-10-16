# NEXORA SYSTEM 2026 V21.6 — Conservación de archivos actualizados externamente

## Comportamiento implementado

- Al activar una opción, NEXORA guarda un respaldo y SHA-256 del original actual (igual que V21.5).
- Al desactivar la opción desde el panel NEXORA, verifica el archivo de destino.
- Si el archivo sigue teniendo el contenido modificado de NEXORA, restaura el original respaldado.
- Si el destino **ha cambiado después de activar** y sigue existiendo, NEXORA **no lo sobrescribe**: conserva sus bytes tal como están, restaura los demás archivos que no hayan cambiado y avisa en pantalla que conservó contenido externo **no verificado**.
- Si el destino desaparece, la restauración se bloquea para evitar daño y conserva los respaldos.
- Verifica con SHA-256 los archivos restaurados y los conservados antes de dar por cerrada la transacción.
- La próxima activación compara el archivo actual con el historial anterior (incluyendo transacciones donde se conservó una actualización externa). Si cambió, **avisa y pide revisión** como V21.5, porque no puede confirmar que el origen del archivo sea oficial.
- Conserva la limpieza propia de NEXORA, música/audio personalizado, enlaces sociales y sistema de licencia; no modifica Cloudflare.

## Limitaciones (no prometer actualización automática universal)

- El cambio externo podría provenir de una actualización legítima, otro modificador o un archivo corrupto. **No se reconoce automáticamente como archivo original oficial**.
- Si el juego actualiza los archivos en otra ruta o un contenedor al que iOS no da acceso, NEXORA no puede detectar ni obtener esos archivos.
- No descarga archivos oficiales ni garantiza compatibilidad entre una opción de una versión antigua y una versión nueva del juego.
- No oculta modificaciones ni elimina registros de seguridad, y no garantiza ausencia de rastros.

## Pruebas

La verificación estática local y la compilación Swift de sintaxis no equivalen a pruebas en iOS. Debe compilarse en GitHub Actions y probarse con archivos propios autorizados.
