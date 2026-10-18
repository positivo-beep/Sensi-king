# NEXORA SYSTEM 2026 V21.4 — Limpieza de temporales propios reforzada

## Lo que se cambió realmente

- Al **desactivar una opción**, se mantiene la restauración verificable del motor y se limpia automáticamente su carpeta `Caches/NEXORA-OwnedTemporaryWorkspaces/<UUID-de-opción>`.
- Si **falla la activación**, se intenta limpiar la misma carpeta temporal propia sin modificar el error ni los archivos de otras opciones.
- Al **volver a iniciar la aplicación**, un mantenimiento en segundo plano examina SOLO esa raíz de temporales propia de NEXORA y elimina carpetas abandonadas con UUID válido que lleven **al menos 48 horas sin modificaciones**. Deja los espacios recientes sin alterar y no sigue enlaces simbólicos como directorios.
- El gestor continúa **rechazando nombres con rutas externas**, **verifica que la carpeta desaparezca tras limpiarla** y tolera limpiarla repetidas veces.
- No se cambió el reproductor de audio de V21.2, la pantalla NEXORA, la lógica de licencias Cloudflare ni los datos de respaldo de transacciones.

## Alcance honesto

La limpieza opera **exclusivamente** sobre la caché temporal que NEXORA administra mediante `NXOwnedTemporaryWorkspaces`. No puede afirmar que elimina cualquier archivo que otra aplicación haya creado ni que borra registros del sistema, huellas de actividad o evidencias de alteraciones. El motor de restauración conserva respaldos y diarios de transacciones para mantener la posibilidad de recuperación.

La verificación SHA-256 confirma bytes de archivos restaurados en rutas contempladas por el motor, pero no que el sistema operativo haya olvidado que se modificaron.

## Pruebas realizadas

Ejecutados con `swiftc` en Linux, sobre código real del módulo:

- Limpieza aislada por opción; la limpieza de A preserva B.
- Rechazo de nombres con `../`.
- Limpieza repetida (idempotente).
- Limpieza automática de una carpeta de 72 horas; una carpeta reciente se conserva.
- Carpeta simbólica que apunta fuera de la raíz: se omite, y el destino permanece intacto.

Los scripts de precomprobación de audio, integridad y estructura también pasaron. **La compilación iOS y el funcionamiento real en el iPhone aún requieren GitHub Actions y pruebas en el dispositivo.**

## Instalación

Igual que antes: extrae el ZIP y copia su **contenido** a la carpeta del repositorio local `Sensi-king`. Revisa los cambios en GitHub Desktop, haz commit, push y espera compilación verde en Actions antes de descargar la IPA.
