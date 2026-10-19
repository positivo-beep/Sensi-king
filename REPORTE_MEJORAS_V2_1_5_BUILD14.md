# NEXORA SYSTEM 2026 — Revisión de activación y restauración v2.1.5 (build 14)

**Entrega:** código fuente completo preparado para compilar en macOS/GitHub Actions. **No se ha compilado, firmado o instalado una IPA en un iPhone en este entorno.**

## Funcionalidad que se reforzó

1. **Activar**: el botón de la interfaz pasa por `DevicePatchService.apply` y `PatchTransaction.apply`. Se conserva la verificación SHA-256 del archivo original actual y la exigencia de un reemplazo actualizado cuando la versión original cambia.
2. **Comprobación justo antes de escribir**: cada destino se comprueba de nuevo después de preparar respaldos y de crear directorios. Si otro proceso modificó el original o creó un archivo nuevo, NEXORA detiene la operación sin sobrescribir ese destino.
3. **Reversión selectiva**: en una activación parcialmente aplicada, el motor solo intenta revertir los archivos que ya había escrito; no toca destinos que estaban esperando su turno.
4. **Respeto a cambios externos**: si un archivo ya escrito cambia de nuevo antes de la reversión, NEXORA no sobrescribe ese contenido y mantiene el diario de recuperación pendiente.
5. **Recuperación de transacciones interrumpidas**: los diarios `.prepared` no autorizan recuperar automáticamente un contenido desconocido. Solo se restablece un contenido verificable; en caso contrario, se interrumpe la operación y se conservan respaldos.
6. **Restauración protegida**: se verifica el estado de cada destino antes de restaurarlo; si cambió después de la inspección, se detiene la restauración normal. La recuperación tras fallos solo revierte archivos modificados por la operación en curso.
7. **Pruebas adicionales**: seis escenarios nuevos (actualización entre preflight y escritura, cambio de la segunda ruta, archivo nuevo concurrente, actualización de una ruta ya modificada, cambio durante restauración, cambio posterior a restauración parcial).
8. **Control de lanzamiento**: scripts, build GitHub Actions, Info.plist, Xcode y nombre de IPA usan v2.1.5/build 14. El workflow exige **19/19** pruebas del motor en macOS antes de empaquetar.

## Pruebas locales realizadas

- **19/19 pruebas del motor correctas** en un entorno Swift Linux con una capa *solo de prueba* de compatibilidad Darwin y SHA-256 de OpenSSL. El proyecto distribuido no incluye esa capa; GitHub Actions usa las librerías Apple nativas.
- Compilación de prueba Swift para validar los tipos de `PatchTransaction` y ejecutar las transacciones.
- Parseo sintáctico de las fuentes Swift del proyecto, comprobaciones estáticas del catálogo, licencia y limpieza, e integridad de estructura del proyecto.
- **Pendiente**: ejecutar los tests y compilar con el toolchain Xcode real, firmar, instalar en iPhone y ensayar el acceso permitido a los archivos objetivo.

## Lo que sigue siendo necesario

- Si cambia el archivo original, el autor debe **aportar un reemplazo nuevo compatible**. El sistema no puede fabricarlo ni asegurar compatibilidad por comparar hashes.
- Cada paquete nuevo debe vincularse al original correspondiente mediante su huella SHA-256 desde el editor de reglas y después importarse/aplicarse de nuevo.
- No se puede prometer el funcionamiento de las opciones que aún carecen de recurso: los reportes del catálogo señalan **21 opciones, de las cuales 8 siguen pendientes de recursos**. Las pruebas estructurales no demuestran que cada botón funcione en un iPhone.
- Una app iOS estándar no tiene permiso para editar contenedores privados de otras apps. No se añadió ningún método para esquivar el aislamiento ni limpiar rastros de terceros. El motor solo puede actuar en destinos a los que el sistema permita acceder legalmente.
- El Worker de licencias de Cloudflare no fue modificado. No incluir `ADMIN_TOKEN` ni secretos de Cloudflare en el proyecto de iPhone.

## Instrucción breve de compilación

Antes de sustituir el proyecto instalado, guarda una copia del repositorio anterior. Extrae este ZIP en tu repo, conservando `.github/workflows`, abre GitHub Actions y ejecuta **Verificar y compilar NEXORA SYSTEM 2026**. Solo cuando el trabajo aparezca en verde, descarga la IPA **NEXORA_SYSTEM_2026_V2_1_5_BUILD14_sin_firmar.ipa**, fírmala con ESign usando tu certificado y prueba con documentos propios antes de considerar esta versión estable.
