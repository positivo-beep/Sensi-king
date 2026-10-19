# NEXORA SYSTEM 2026 — Auditoría y mejoras integrales

**Versión del código fuente:** 2.1.3 (build 12)  
**Estado:** revisión local y pruebas ejecutables; **NO** es una IPA nueva compilada, firmada ni probada en iPhone.

## Cambios realizados sobre la versión anterior (2.1.2 build 11)

### A. Limpieza temporal propia (código cambiado y prueba local ejecutada)
- Los nombres de temporales solo permiten caracteres ASCII seguros, sin controles ni saltos de línea, máximo 128 bytes.
- La limpieza manual no borra de forma recursiva espacios que contienen enlaces simbólicos, subcarpetas u objetos desconocidos; informa del problema.
- La limpieza automática conserva temporales recientes, protegidos y no verificables, sin abandonar el análisis de los demás si encuentra un directorio inseguro.
- Las copias de seguridad, diarios y datos ajenos no forman parte de estos espacios propios.
- Se corrigió una prueba incoherente que declaraba antiguo el directorio pero no su archivo. Ahora comprueba ambos.
- Casos nuevos: nombre inválido, enlace inesperado, subdirectorio inesperado, carpetas protegidas.

### B. Reemplazo seguro de archivos (código cambiado; prueba macOS preparada)
- Requiere archivos ordinarios, no directorios, enlaces simbólicos ni entradas especiales.
- Comprueba tamaño y fecha de modificación del origen y destino antes de la sustitución final.
- Confirma el tamaño del archivo de preparación antes del cambio atómico.
- Si la copia no es coherente, conserva el destino y no ejecuta el renombrado final.
- Prueba automática añadida para GitHub Actions: copia normal, archivo vacío, mismo archivo, enlace, directorio y limpieza del staging.

### C. Limpiador limitado de caché (código cambiado; prueba macOS preparada)
- Suma de tamaños protegida contra desbordamientos.
- Límite de profundidad (64 niveles) durante el análisis y la limpieza; carpetas anormales profundas se conservan y se contabilizan como problema, no como limpieza correcta.
- Prueba nueva de limpieza selectiva que comprueba que `Documents`, archivos externos y enlaces no se eliminen.
- El alcance sigue limitado a rutas expresamente permitidas por el código. No se añadió borrado general ni eliminación de registros.

### D. Compilación e integridad
- Ambos archivos de workflow de GitHub actualizados para crear artefactos **NEXORA_SYSTEM_2026_V2_1_3_BUILD12_sin_firmar.ipa**; antes seguían usando nombres build9/build10.
- Versión de Info.plist, configuración Xcode, scripts de release e inspección IPA sincronizados (2.1.3 / 12).
- Nuevas pruebas de reemplazo y limpieza limitada integradas en el workflow macOS.
- Manifiesto SHA-256 actualizado para los archivos cambiados.

## Validación y alcance real

| Parte | Qué se pudo comprobar | Qué falta |
|---|---|---|
| Limpieza de espacios temporales propios | Test Swift local pasó | Ejecución real bajo iOS y pruebas de estrés |
| Reemplazo de archivos | Sintaxis Swift validada | Compilación y prueba Swift/Darwin en macOS; prueba en iPhone |
| Limpieza limitada | Sintaxis Swift validada | Compilación y prueba Swift/Darwin en macOS; prueba en iPhone |
| Licencias dentro de la IPA | Comprobaciones estáticas de HTTPS, Keychain, revalidación y vencimiento | Integración en vivo con el Worker, expiración y revocación reales |
| Motor de aplicar/restaurar | Revisiones existentes de integridad conservadas | Prueba con archivos autorizados en dispositivo y recuperación tras interrupciones |
| Catálogo y opciones | Verificadores estáticos conservados | Prueba individual de cada botón y recurso en iPhone |
| Compatibilidad iOS | Código y metadatos revisados | Confirmación por versión/modelo con un dispositivo real |
| Panel Cloudflare/D1 | No fue modificado | Auditoría del `worker.js` publicado y pruebas de su base de datos |
| IPA/ESign | CI preparado | Build Xcode, firma y validación en iPhone |

**Restricción:** iOS no permite garantizar a una app ordinaria el acceso a contenedores de otras apps. No se implementó ningún mecanismo para eludir esta protección ni para borrar rastros, registros o datos de terceros.

## Seguridad de credenciales
- **No** se añadieron `ADMIN_TOKEN`, `LICENSE_PEPPER` ni credenciales del panel a la IPA.
- En una captura anterior quedó parcialmente visible el token administrativo: rotarlo y almacenarlo como **Secret** en Cloudflare antes de publicar.
- El código activo del Worker Cloudflare no estaba disponible; ningún cambio de panel o base de datos fue desplegado.

## Próximos pasos
1. Guardar respaldo del repositorio actual y revisar el ZIP nuevo.
2. Subir los archivos a GitHub, ejecutar Actions y compartir el registro si hay errores.
3. Instalar la IPA firmada solo después de probar activación, restauración, limpieza y cada función de la interfaz.
4. Compartir aparte el `worker.js` actual **sin secretos** para auditar el backend real.
