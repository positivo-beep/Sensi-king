# NEXORA SYSTEM 2026 — Compilar la revisión 2.1.9 (build 18)

**Este ZIP contiene código fuente, NO una IPA compilada.** No se cambió tu Worker de Cloudflare.

## Guía sencilla desde tu PC

1. Guarda primero una copia del proyecto que ya tienes en GitHub.
2. Extrae el ZIP nuevo. Verás las carpetas `.github`, `ThreeOneOSFive`, `scripts` y los documentos.
3. Copia el **contenido** del ZIP a la carpeta raíz de tu repositorio (donde está `.github`). No lo pongas dentro de una segunda carpeta `ThreeOneOSFive` por error. Confirma que los archivos nuevos aparecen en GitHub Desktop.
4. Revisa los cambios, crea un commit y súbelo a la rama `main` de tu repositorio. Usa un repositorio privado si los recursos no están destinados a publicarse.
5. En GitHub abre **Actions → Verificar y compilar NEXORA SYSTEM 2026**. Espera al resultado verde.
6. En **Artifacts**, descarga `NEXORA_SYSTEM_2026_V2_1_9_BUILD18_sin_firmar`. Contendrá la IPA sin firmar con el mismo nombre y extensión `.ipa`.
7. Una vez revisada la compilación y el resultado de las pruebas, podrás firmar la IPA con ESign usando tu certificado válido.

Si Actions sale rojo, no instales la IPA anterior pensando que es la nueva. Abre la ejecución fallida y guarda el log correspondiente.

## ¿Qué validan las pruebas de GitHub?

- Estructura del proyecto y recursos incluidos.
- 21 pruebas funcionales de activación, restauración, actualización y protección de respaldos corruptos.
- Limpieza de espacios temporales propios.
- Limpieza limitada de caché (prueba nueva en macOS).
- Reemplazo seguro de archivos (prueba nueva en macOS).
- Comprobaciones de recursos UnityFS de la estructura empaquetada.
- Compilación Xcode de la app sin firma.

**No certifican** que iOS conceda permisos sobre otra aplicación, que todas las funciones del juego operen en el teléfono ni que las licencias de Cloudflare estén correctas. Eso requiere comprobaciones en el dispositivo y en el servidor.

Antes de publicar, cambia el token administrativo que apareció parcialmente en una captura y guárdalo como Secret en Cloudflare. No envíes credenciales en los chats, repositorios ni capturas.
