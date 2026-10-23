# NEXORA SYSTEM 2026 — 2.0.2 Build 10 (candidato de prueba)

**Base:** proyecto Build 9 (rama conservadora) reconstruido desde el código recuperado de Build 8. 
**NO procede de Build 18.** El identificador original y las funciones internas del motor anterior permanecen intactos.

## Mejoras comprobadas

- Personaje Rainbow (en lugar de Rojo) y recursos de HOLO P/HOLO ARM incorporados desde Build 9.
- Sistema existente de licencia Cloudflare y avisos de vencimiento conservados sin cambios.
- Sistema existente de respaldos, SHA-256, protección de cambios externos y restauración conservado sin cambios.
- Limpieza manual/automática de temporales propios: operaciones serializadas para no crear/borrar simultáneamente una misma carpeta dentro del proceso. `cleanAll` respeta las opciones protegidas.
- Prueba dinámica de 48 escrituras concurrentes y preservación de opción protegida.
- La automatización de compilación incorpora una prueba **funcional** de reemplazo de archivos *propios* (reemplazo, mismos archivos, enlaces simbólicos, carpetas y archivos vacíos), antes de crear IPA.
- Control de hashes de los ocho archivos originales del motor, para detectar regresiones involuntarias.

## Qué no se ha hecho

- No se ha alterado ni recreado el código de exploit, acceso de contenedores privados ni mecanismos de activación de la IPA original.
- No se ha realizado una compilación en Xcode/macOS en este entorno ni pruebas en un iPhone.
- No se afirma compatibilidad con acceso a archivos privados de otras apps, ni que las activaciones de Free Fire funcionen. Debe verificarse en un entorno autorizado.
- No hay una prueba de conexión en vivo con el Worker de Cloudflare; las pruebas de licencias son estáticas.

## Instalación de prueba

Conservar la IPA original y sus respaldos. Compilar primero en la rama de pruebas; no reemplazar una instalación que funcione sin hacer copia de seguridad. Cuando GitHub Actions supere los controles, probar los archivos propios y el inicio de sesión en el dispositivo.
