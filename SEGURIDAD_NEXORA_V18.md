# NEXORA SYSTEM 2026 — Seguridad V18

## Cambios en la aplicación (sin cambiar la interfaz)

- Conserva `/v1/activate` y `/v1/validate` con `key` y `device_id`; **no cambia el protocolo de tu Worker**.
- La key permanece guardada mediante Keychain en este dispositivo y se consulta al servidor cuando corresponde.
- La comunicación de licencias utiliza `URLSessionConfiguration.ephemeral` sin cookies ni caché persistente.
- Solo el servidor HTTPS configurado puede autorizar una respuesta; se rechazan redirecciones y respuestas mayores de 16 KB.
- Una licencia solo permite entrar si hay **HTTP 2xx** y `ok == true` y `active == true`.
- Las fechas de expiración malformadas, cuando el servidor las envía, no se aceptan como licencias sin vencimiento.
- Se mantiene el bloqueo de licencias vencidas/revocadas. No se muestran detalles técnicos de fallos de red al usuario.
- Un HTTP 429 informa que hubo demasiados intentos y no concede acceso.

## Cambios que debes hacer en TU servidor Cloudflare (no aplicados aquí)

1. **Validación siempre en servidor:** fechas de vencimiento, revocación, dispositivos autorizados y límite de dispositivos deben consultarse en almacenamiento privado del Worker; no confiar en datos enviados desde la IPA.
2. **Rate limiting:** limitar activaciones y validaciones fallidas por IP y por key; emitir 429 cuando se exceda la cuota. La app V18 interpreta 429.
3. **Secreto de administración:** mantenerlo en Cloudflare Worker Secrets; nunca en la IPA, GitHub o archivos públicos. Separar rutas administrativas de `/v1/activate` y `/v1/validate`.
4. **Almacenar claves de forma segura:** idealmente, un hash/HMAC para las keys en la base de datos, en vez de keys en texto plano. Proteger la base de datos, logs y copias.
5. **Respuesta de vencimiento real:** enviar `expires_at` con fecha ISO 8601 e idealmente `duration_days`, junto con `ok`, `active` y motivos de rechazo (`expired`, `revoked`, `device_limit`).
6. **Restricción por dispositivo:** `device_id` es un identificador generado por el cliente, no una prueba criptográfica de identidad; puede copiarse de un dispositivo comprometido. Para mayor solidez considerar App Attest/DeviceCheck con firma y entitlements adecuados; **no asumir que ESign admite esto**.
7. **Verificaciones constantes:** la revocación remota solo puede comprobarse cuando la app se comunica con Cloudflare; no puedes garantizar bloqueo inmediato sin conexión.

## Limitaciones honestas

Ninguna app cliente es imposible de crackear o parchear, especialmente en un dispositivo modificado. Sin un backend que rechace licencias no autorizadas, la seguridad del cliente es insuficiente. La IPA puede ser reempaquetada o alterada; estos cambios reducen exposición accidental y respuestas falsas, pero **no implementan certificación del ejecutable ni protección criptográfica anti-manipulación**.

## Pruebas que faltan

- GitHub Actions con Xcode: compilación de V18.
- iPhone con ESign: key real activa, key inválida, revocada, vencida, offline y cuando Cloudflare responde 429.
- Verificar servidor: rate limiting, revocación y controles de administración.

**No incluimos keys reales ni secretos en este ZIP.** No se cambió el panel visual ni el motor 3105.
