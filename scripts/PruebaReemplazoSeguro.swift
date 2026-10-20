import Foundation

@main
struct PruebaReemplazoSeguro {
    static func main() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent(
            "nexora-replace-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }

        let destination = folder.appendingPathComponent("original.dat")
        let source = folder.appendingPathComponent("replacement.dat")
        try Data("ORIGINAL".utf8).write(to: destination)
        try Data("NUEVO SEGURO".utf8).write(to: source)
        let receipt = try FileReplacementService.replace(target: destination, with: source)
        guard receipt.byteCount == Int64(Data("NUEVO SEGURO".utf8).count),
              try Data(contentsOf: destination) == Data("NUEVO SEGURO".utf8) else {
            fatalError("No verificó correctamente el reemplazo")
        }
        print("1/16 Reemplazo ordinario: verificado.")

        // El tamaño cero es válido y no puede dar un falso negativo en macOS.
        try Data().write(to: source)
        let zero = try FileReplacementService.replace(target: destination, with: source)
        guard zero.byteCount == 0, try Data(contentsOf: destination).isEmpty else {
            fatalError("Falló la verificación de archivo vacío")
        }
        print("2/16 Archivo vacío: reemplazo verificado.")

        do {
            _ = try FileReplacementService.replace(target: destination, with: destination)
            fatalError("Se permitió reemplazar por sí mismo")
        } catch FileReplacementError.sameFile { }
        print("3/16 Mismo archivo: bloqueado.")

        let shortcut = folder.appendingPathComponent("source-link.dat")
        try fm.createSymbolicLink(at: shortcut, withDestinationURL: source)
        do {
            _ = try FileReplacementService.replace(target: destination, with: shortcut)
            fatalError("Se siguió un enlace de origen")
        } catch FileReplacementError.symbolicLinkUnsupported { }
        print("4/16 Enlace de origen: bloqueado.")

        let unknownFolder = folder.appendingPathComponent("folder")
        try fm.createDirectory(at: unknownFolder, withIntermediateDirectories: false)
        do {
            _ = try FileReplacementService.replace(target: destination, with: unknownFolder)
            fatalError("Una carpeta se aceptó como archivo")
        } catch FileReplacementError.sourceIsDirectory { }
        print("5/16 Carpeta como origen: bloqueada.")

        let hardlink = folder.appendingPathComponent("hardlink.dat")
        try fm.linkItem(at: destination, to: hardlink)
        do {
            _ = try FileReplacementService.replace(target: destination, with: hardlink)
            fatalError("Se permitió autorrreemplazo por enlace duro")
        } catch FileReplacementError.sameFile { }
        try fm.removeItem(at: hardlink)
        print("6/16 Enlace duro al mismo archivo: bloqueado.")

        let linkTarget = folder.appendingPathComponent("target-link.dat")
        try fm.createSymbolicLink(at: linkTarget, withDestinationURL: destination)
        do {
            _ = try FileReplacementService.replace(target: linkTarget, with: source)
            fatalError("Se siguió un enlace de destino")
        } catch FileReplacementError.symbolicLinkUnsupported { }
        print("7/16 Enlace de destino: bloqueado.")

        // Copia real por varios bloques de 1 MiB.
        let large = Data(repeating: 0xA5, count: 2 * 1_024 * 1_024 + 13)
        try large.write(to: source, options: .atomic)
        let big = try FileReplacementService.replace(target: destination, with: source)
        guard big.byteCount == Int64(large.count), try Data(contentsOf: destination) == large else {
            fatalError("Reemplazo por bloques incorrecto")
        }
        print("8/16 Copia grande por bloques: verificada.")

        // Un archivo modificado NUEVO puede reemplazar el anterior si fue aportado
        // expresamente; la validación de versión SHA-256 vive en PatchTransaction.
        let nextVersion = Data("REEMPLAZO-V2-NUEVO".utf8)
        try nextVersion.write(to: source, options: .atomic)
        _ = try FileReplacementService.replace(target: destination, with: source)
        guard try Data(contentsOf: destination) == nextVersion else {
            fatalError("El reemplazo actualizado no se aplicó")
        }
        print("9/16 Reemplazo de versión actualizada: verificado.")

        #if REPLACEMENT_TESTING
        // Reproduce de manera determinista un origen reemplazado durante la copia.
        FileReplacementService.testAfterCopy = {
            try Data("CAMBIO-MIENTRAS-COPIABA".utf8).write(to: source, options: .atomic)
        }
        do {
            _ = try FileReplacementService.replace(target: destination, with: source)
            fatalError("Se publicó un origen que cambió durante la copia")
        } catch FileReplacementError.sourceChangedDuringCopy { }
        FileReplacementService.testAfterCopy = nil
        guard try Data(contentsOf: destination) == nextVersion else {
            fatalError("Se alteró el destino después de detectar origen cambiante")
        }
        print("10/16 Origen actualizado durante copia: bloqueado sin pérdida.")

        // Otro proceso cambió el destino: no pisarlo con un archivo viejo.
        let external = Data("CAMBIO-EXTERNO".utf8)
        FileReplacementService.testAfterCopy = {
            try external.write(to: destination, options: .atomic)
        }
        do {
            _ = try FileReplacementService.replace(target: destination, with: source)
            fatalError("Se sobrescribió el destino actualizado externamente")
        } catch FileReplacementError.targetChangedDuringCopy { }
        FileReplacementService.testAfterCopy = nil
        guard try Data(contentsOf: destination) == external else {
            fatalError("Se perdió la actualización externa")
        }
        print("11/16 Destino actualizado durante copia: preservado.")
        #else
        print("10-11/16 Casos de concurrencia: requieren REPLACEMENT_TESTING.")
        #endif

        // Un origen inexistente no debe causar ninguna modificación del destino.
        let missingSource = folder.appendingPathComponent("no-existe.bin")
        do {
            _ = try FileReplacementService.replace(target: destination, with: missingSource)
            fatalError("Se aceptó un origen ausente")
        } catch FileReplacementError.sourceMissing { }
        guard try Data(contentsOf: destination) == external else {
            fatalError("Se perdió el destino al faltar el origen")
        }
        print("12/16 Origen ausente: destino preservado.")

        #if REPLACEMENT_TESTING
        // Cambiar bytes SIN cambiar la longitud ni el inode. Ajustar mtime a
        // una fecha conocida hace que la detección sea determinista en APFS y Linux.
        // La prueba original usaba .atomic y solo comprobaba cambios de inode.
        let beforeInPlaceSource = try Data(contentsOf: source)
        FileReplacementService.testAfterCopy = {
            let fd = try FileHandle(forWritingTo: source)
            defer { try? fd.close() }
            try fd.seek(toOffset: 0)
            try fd.write(contentsOf: Data(repeating: 0x51, count: beforeInPlaceSource.count))
            try fd.synchronize()
            try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 946684800)],
                                 ofItemAtPath: source.path)
        }
        do {
            _ = try FileReplacementService.replace(target: destination, with: source)
            fatalError("Se aceptó un cambio del origen con tamaño idéntico")
        } catch FileReplacementError.sourceChangedDuringCopy { }
        FileReplacementService.testAfterCopy = nil
        guard try Data(contentsOf: destination) == external else {
            fatalError("El cambio del origen de igual tamaño alteró el destino")
        }
        print("13/16 Cambio in situ del origen: bloqueado.")

        let originalDestinationLength = external.count
        let externalInPlace = Data(repeating: 0x42, count: originalDestinationLength)
        FileReplacementService.testAfterCopy = {
            let fd = try FileHandle(forWritingTo: destination)
            defer { try? fd.close() }
            try fd.seek(toOffset: 0)
            try fd.write(contentsOf: externalInPlace)
            try fd.synchronize()
            try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 946684800)],
                                 ofItemAtPath: destination.path)
        }
        do {
            _ = try FileReplacementService.replace(target: destination, with: source)
            fatalError("Se sobrescribió un destino alterado con tamaño idéntico")
        } catch FileReplacementError.targetChangedDuringCopy { }
        FileReplacementService.testAfterCopy = nil
        guard try Data(contentsOf: destination) == externalInPlace else {
            fatalError("Se perdió el cambio externo con tamaño idéntico")
        }
        print("14/16 Cambio in situ del destino: preservado.")

        // Si un proceso mueve o elimina el destino mientras copiamos, jamás
        // publicar una copia sobre una ruta que ha dejado de existir.
        FileReplacementService.testAfterCopy = { try fm.removeItem(at: destination) }
        do {
            _ = try FileReplacementService.replace(target: destination, with: source)
            fatalError("Se recreó sin permiso el destino que fue eliminado")
        } catch FileReplacementError.targetMissing { }
        FileReplacementService.testAfterCopy = nil
        guard !fm.fileExists(atPath: destination.path) else {
            fatalError("Se recreó el destino externo eliminado")
        }
        print("15/16 Destino eliminado por tercero: no recreado.")
        #else
        print("13-15/16 Requieren REPLACEMENT_TESTING.")
        #endif

        let leftovers = try fm.contentsOfDirectory(atPath: folder.path).filter {
            $0.hasPrefix(".3105-replacement-")
        }
        guard leftovers.isEmpty else { fatalError("Quedaron archivos de staging sin limpiar") }
        print("16/16 Temporales de reemplazo: sin residuos.")
        print("REEMPLAZO: 16/16 comprobaciones correctas")
    }
}
