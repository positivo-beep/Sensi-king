# NEXORA — entrega conservadora (22 octubre 2026)

Objetivo: minimizar cambios para evitar regresiones de la pantalla de key.

## Corrección realizada
- Restaurado **exactamente** el contenido del archivo `ThreeOneOSFive/App.swift` al SHA-256 de la versión fuente previa a la vigilancia (`8dd1263ef1196be0c40c95d50683200f60b295927c64488010d9432761fadc9c`). Se eliminaron los tres cambios del constructor del panel introducidos en la entrega anterior.
- La vigilancia añadida sigue en `ContentView.swift`, con comienzo a los 30 segundos de entrar, comprobación cada 5 minutos mientras hay primer plano, y bloqueo solo por destino cambiado.
- Los scripts de comprobación estática se ajustaron al contrato restaurado. No se modificó el Worker ni el flujo de API de keys.

## Importante
- La base IPA enviada por el usuario está **intacta**. Este proyecto no es una IPA compilada.
- Identificador, endpoint y Keychain coinciden con la IPA de referencia, pero los tests estáticos NO prueban que la app pueda iniciar sesión en un dispositivo real.
- La vigilancia conoce **15 opciones sobre 4 archivos de destino**. Sin respaldo previo, permiso de lectura o acceso a la nueva versión, no puede afirmar que detectó todos los parches ni identificar origen oficial.
- Antes de sustituir la IPA que funciona: compilar en macOS y probar en dispositivo el inicio con una key válida, key inválida, sin red, reabrir desde segundo plano y activación/desactivación con archivos propios de prueba. No declarar liberación si alguna de esas pruebas falla.

- Inventario actualizado por cambio deliberado en App.swift: `4f6e81092f1070745221172d703deab234de0f8f88a4d527ca7857d12bb84d63` -> `8dd1263ef1196be0c40c95d50683200f60b295927c64488010d9432761fadc9c`.
