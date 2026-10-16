# NOTA V21.6

Esta es la versión para compilar. Copia el contenido **dentro** de tu repositorio Sensi-king, conserva la carpeta `.git` y publica con GitHub Desktop. Revisa GitHub Actions y prueba primero con archivos de demostración propios. V21.6 preserva cambios externos sin identificarlos como oficiales. No modifica Cloudflare.

# NEXORA SYSTEM 2026 — Compilar para iPhone

**Estado:** código fuente preparado, no una IPA ya compilada. Solo la ejecución en Xcode de GitHub Actions confirma la compilación iOS.

## Qué incluye
- Acceso mediante Cloudflare con `/v1/activate` y `/v1/validate`.
- Interfaz de key negra/morada y panel NEXORA con categorías horizontales e interruptores; sin pestaña pública de archivos ni opción de eliminar keys del servidor. La autoprueba local está plegada en Configuración.
- Motor fuente de 3105 para paquetes `.3105` con copia/restauración. No incluye modificaciones de terceros ni garantiza permisos de acceso a otras aplicaciones.
- Tarjetas AIM sin un paquete asociado se muestran deshabilitadas; no activan ningún mod ficticio.
- Contador de tiempo restante si el Worker responde `expires_at` y/o campos de duración.
- Discord/WhatsApp: sus URLs están pendientes de configurar porque no se facilitaron.

## Guía desde Windows
1. Extrae este ZIP en una carpeta. Abre esa carpeta: dentro están `.github`, `ThreeOneOSFive`, `ThreeOneOSFive.xcodeproj` y el resto de los archivos.
2. En GitHub, crea un **repositorio privado nuevo y vacío**, para no mezclar los archivos antiguos del proyecto SwiftUI con los del motor 3105. Ejemplo: `NEXORA-SYSTEM-2026`.
3. Ve a **Add file > Upload files** y arrastra todo el **contenido** de la carpeta extraída (no el ZIP entero). Comprueba especialmente que el archivo `.github/workflows/build-nexora-ios.yml` esté subido.
4. Pulsa **Commit changes** en la rama `main`.
5. Ve a **Actions > Verificar y compilar NEXORA SYSTEM 2026 > Run workflow** si no se ejecutó automáticamente.
6. Si sale verde, entra en esa ejecución y descarga **NEXORA_SYSTEM_2026_3105_sin_firmar** de **Artifacts** (GitHub lo entrega como ZIP).
7. Extrae el ZIP del artefacto. Contendrá `NEXORA_SYSTEM_2026_3105_sin_firmar.ipa`, para firmar con ESign con un certificado/perfil válido.
8. Si sale rojo, entra en `build`, abre el paso fallido y envíame el registro o descarga el artefacto `NEXORA_LOG_COMPILACION` si existe. No vuelvas a ejecutar sin corregir el error.

**Nota sobre permisos:** el identificador de bundle de 3105 y su lógica interna no otorgan por sí mismos acceso garantizado a archivos de otros juegos. No uses archivos importantes para la primera prueba. La edición y la firma de una IPA pueden afectar el funcionamiento del acceso.

**Acerca de las keys:** la pantalla NEXORA verifica tu Cloudflare. Quitar la licencia almacenada localmente por cerrar sesión no revoca ninguna key; únicamente el panel de administración puede revocarla en el servidor.
