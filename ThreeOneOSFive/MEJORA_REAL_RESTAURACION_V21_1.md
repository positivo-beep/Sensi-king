# NEXORA SYSTEM 2026 — V21.1

## Qué se mejoró realmente

- Al desactivar una opción, NEXORA restaura los archivos desde los respaldos disponibles.
- Antes de marcar la operación como restaurada, valida mediante **SHA-256** el contenido de **cada** archivo que existía antes.
- Para archivos creados por la opción, confirma que ya no existan.
- Si falla alguna comprobación, el mecanismo de recuperación de la transacción intenta dejar los archivos como estaban inmediatamente antes de restaurar y muestra un error.
- Se preserva el sonido «Opción activada» de V21 (voz iOS hasta recibir un audio personalizado), los enlaces y el flujo de licencias.
- El proyecto no pretende alterar ni suprimir registros de seguridad ni garantizar invisibilidad de los cambios.

## Nota

Esta versión incluye cambios de código verificados sintácticamente y mediante los scripts locales. Se debe **compilar y probar en iPhone** antes de considerarla validada en el dispositivo. Se requiere conservar los respaldos de NEXORA mientras haya cambios activos.
