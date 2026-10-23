# NEXORA - vigilar después del login (revisión para probar)

**Fuente base:** Build 16R HOLO PJ que precedió a Build 17S (no se puede demostrar que los binarios firmados sean byte por byte los generados por esta fuente).

**Cambios intencionados del código Swift:** exactamente dos archivos.

- `ThreeOneOSFive/App.swift`: mantiene sin modificar la lógica de red Cloudflare, Keychain, modelo de licencia y revalidación; solo construye `ContentView()` cuando el servidor permite entrar al panel (se elimina el trabajo prematuro de construirlo durante `Verificando NEXORA`).
- `ThreeOneOSFive/ContentView.swift`: vigilancia y bloqueo individual por fichero, comprobación inicial 30 segundos después de que el panel aparezca, siguientes revisiones cada 5 minutos en primer plano. Fallo de lectura no equivale a parche confirmado.

**No se ha modificado:** licencias Cloudflare, motor de restauración, funciones del catálogo, texturas ni hologramas.

La IPA anterior que el usuario confirmó que abría correctamente y los datos de instalación deben conservarse. La compilación Xcode/macOS y prueba en iPhone son indispensables; esta revisión no garantiza que una caída externa del servicio de licencias pueda evitarse.
