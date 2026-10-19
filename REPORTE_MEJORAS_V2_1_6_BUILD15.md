# NEXORA SYSTEM 2026 — Activación más segura v2.1.6 (build 15)

**Alcance:** código fuente de la IPA, no servidor Cloudflare. La compilación final con Xcode y la instalación en iPhone siguen pendientes.

## Cambios de esta versión

1. **Exclusión mutua:** `PatchTransaction.apply`, `restore` y `resetToAppliedState` comparten un bloqueo de mutaciones por proceso. Evita que dos tareas de NEXORA escriban simultáneamente el mismo destino y creen respaldos contradictorios.
2. **Historial verificable:** antes de activar, se revisan los diarios de respaldo existentes. Si hay un `journal.plist` dañado, con IDs inconsistentes o formato no admitido, la nueva activación queda bloqueada sin modificar archivos.
3. **Errores claros:** un diario incompatible muestra un aviso en español desde el panel de opciones que pide revisar los respaldos, sin aconsejar borrarlos.
4. **Dos nuevas pruebas funcionales:** recuperación frente a diario corrupto y activaciones paralelas del mismo archivo.
5. **Entrega diferenciada:** versión 2.1.6 / build 15 en ambos Info.plist, Xcode y workflow. GitHub Actions exige **21/21** pruebas del motor antes del empaquetado.

## Evidencias locales

- **21/21 pruebas** ejecutadas sobre directorios temporales aislados usando Swift para Linux con módulos de compatibilidad de prueba para Darwin y SHA-256 de OpenSSL. Las capas de prueba no se incluyen en el ZIP.
- Análisis sintáctico del código Swift y comprobaciones estáticas de integración.
- Sin compilación Xcode ni pruebas en dispositivo en este entorno.

## Límites importantes

- NEXORA no puede acceder por sí sola al contenedor privado de otra aplicación en iOS estándar; no se añadieron métodos para evadir esas restricciones.
- El catálogo incluye botones que no disponen de paquete real. Un motor de respaldo correcto no fabrica recursos ni convierte esas opciones en funcionales.
- Cambios externos a los archivos pueden impedir una restauración automática; se conservan diarios y respaldos para revisión.
- No se puede afirmar que una IPA no instalada funcione al 100 %. **No sustituyas tu versión funcional antes de probar.**
