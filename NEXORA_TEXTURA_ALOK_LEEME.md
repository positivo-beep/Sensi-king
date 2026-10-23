# NEXORA — TEXTURA ALOK (prueba incremental de Build 16R)

- Cambio funcional único: TEXTURA PERSONALIZADA (pendiente) se sustituye por **TEXTURA ALOK** en la pestaña **TEXTURA**.
- Archivo binario original aportado por el usuario, sin edición de bytes, SHA-256: `623efcd8995dc27ba939595843dd29b99cf98f944db528895534e714e9136df5`.
- Se incorpora como `NXModTexturaAlok.dataset` y se utiliza el mismo sistema de validación previa, respaldo y restauración de Build 16R.
- Ruta relativa de destino **inferida** a partir de los patrones del catálogo ya existente: `Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles/optionalab_avatar_66.1GZrX1l5Sm~2FgqXYqB7dDyULWdn4~3D`.
- **No se ha verificado que la ruta exista en el teléfono** ni que iOS autorice escribir ahí. Si no está disponible, NEXORA mostrará un error sin reemplazar el archivo. No es posible asegurar la activación real antes de comprobar destino y permisos.
- La verificación UnityFS solo cubre contenedor/cabecera/tamaño, no certifica compatibilidad con la versión instalada del juego.
- Se preservan todas las opciones y la lógica de Build 16R; no se modifica el motor de permisos, ni se evade el aislamiento de iOS.
- Para evitar regresiones: probar en rama nueva y conservar Build 16R instalada hasta validar ALOK. Compilación iOS real: GitHub Actions macOS, pruebas de aplicación y restauración pendientes.
