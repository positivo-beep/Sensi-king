# NEXORA SYSTEM 2026 — entrega de estabilidad para compilar (22 oct 2026)

## Qué es esta entrega

Proyecto iOS fuente completo, derivado de `NEXORA_SYSTEM_2026_PROYECTO_CONSERVADOR.zip`.
Contiene `.github/workflows/build-nexora-ios.yml`, `ThreeOneOSFive.xcodeproj`, fuentes Swift,
`Assets.xcassets`, recursos, `deploy/` y `scripts/`. No es una IPA compilada.

## Correcciones de entrada y vigilancia

1. La URL, rutas `/v1/validate`/`/v1/activate`, Keychain y criterios `ok && active` de licencia no cambian.
2. La vista principal se construye únicamente cuando el servidor permite el acceso: `NexoraLicenseBoundary` retiene un creador perezoso, no una vista creada en `init`.
3. Protección de espera: si una petición queda colgada 35 s, se desbloquea la interfaz de licencia con aviso. Una respuesta tardía no autoriza el panel.
4. La vigilancia de archivos inicia **30 s después de mostrar el panel** y repite cada 5 minutos solo en primer plano y con licencia válida.
5. El escaneo es despachado a una tarea de baja prioridad; no ejecuta hashing sincrónico en el hilo principal. Si se cierra sesión o se sale del primer plano, descarta el resultado.
6. Un fallo de lectura NO equivale a parche detectado; no borra originales, ni sobrescribe automáticamente archivos desconocidos.
7. El comprobador de actualizaciones es independiente del flujo de autenticación.

## Mejoras pedidas: actualización y origen

- El gestor YA soporta actualizar recursos de NEXORA y parejas original/variante con SHA-256 y sin sobrescribir respaldos. La pareja correcta se aplica solo si coincide el SHA-256 del original accesible. Una modificación no se puede adaptar matemáticamente a cualquier versión nueva sin una variante compatible.
- Ahora se aceptan catálogos firmados Ed25519 de tu propia fuente NEXORA, junto con una clave pública fijada en Ajustes. El formato JSON de envoltura es `{"format":"nexora-ed25519-v1","payloadBase64":"BASE64_JSON_MANIFIESTO","signatureBase64":"BASE64_FIRMA_ED25519"}`. Se firma el **contenido binario decodificado de `payloadBase64`** (no la cadena Base64). `payloadBase64` contiene el JSON existente con `schema`, `resources` y opcionalmente `compatiblePairs`.
- Si tienes una clave pública configurada, todo catálogo sin firma o con firma inválida se rechaza. Sin configurar clave, un catálogo anterior no firmado solo se permite para `resources` propios; no se instalan parejas de binarios modificados.
- La firma verifica que el catálogo lo autorizó quien controla esa clave; **no demuestra que un parche de otro videojuego sea oficial**. Para eso hacen falta metadatos comprobables del distribuidor del juego. Un SHA-256 diferente solo prueba cambio en bytes.
- Para crear y firmar tu propio catálogo se incluye `scripts/firmar_catalogo_nexora.py` (`python -m pip install cryptography`). Genera la clave privada **fuera del repositorio**, publica el JSON firmado y pega **solo** la clave pública Base64 en los ajustes de NEXORA. Nunca incluyas la clave privada en GitHub o una IPA.
- No se incluyen claves privadas ni secretos en este ZIP. No se publica ninguna variante nueva que el usuario no haya proporcionado.

## Antes de instalar en un dispositivo

**Pruebas locales en este entorno:** `python3 scripts/verificar_estabilidad_nexora_entrega.py` y `swiftc -frontend -parse`.
No equivalen a compilar iOS ni validar Cloudflare desde el teléfono.

**Guía desde otra PC:** descomprime el ZIP, sube **todo el contenido de la carpeta** (incluidas las carpetas `.github`, `ThreeOneOSFive`, `ThreeOneOSFive.xcodeproj`, `scripts` y `deploy`) a un repositorio GitHub. En Actions ejecuta **Verificar y compilar NEXORA SYSTEM 2026** con `Run workflow`. Descarga el artifact `.ipa` sin firma que produzca. Esa compilación se ejecuta en macOS de GitHub, no en Windows.

**Prueba primero y conserva la IPA funcional:** key válida, key inválida, fallo de Internet, espera de timeout, clave vencida, abrir/cerrar la app, acceder al panel, activar auditoría, comprobar y restaurar solo recursos de prueba autorizados. No sustituyas la versión buena hasta confirmar estas pruebas.

**Limitaciones comprobadas:** no puedo ejecutar Xcode/iOS ni confirmar el Worker vivo en este contenedor. Las comprobaciones son análisis del código, formato y pruebas que sí corren aquí; no una garantía de cero fallos.

## Comprobación antes de usar la otra PC

`python3 scripts/verificar_base_ipa_recibida.py RUTA_A_TU_IPA_ORIGINAL` coteja bundle ID, endpoint, Keychain y controles del login frente a la IPA original. `python3 scripts/verificar_estabilidad_nexora_entrega.py` valida las invariantes y firma.

La app no puede determinar si un parche de un videojuego es oficial solo por cambios de contenido. Puede avisar de diferencias y comprobar firmas de **tu catálogo**; publicar variantes para nuevos originales requiere tener esos archivos compatibles preparados y firmados.
