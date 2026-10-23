import Foundation

@main
struct Main {
    static func main() throws {
        let fm = FileManager.default
        let message = try NXOwnedTemporaryWorkspaces.selfTest()
        guard message.hasPrefix("Limpieza OK") else {
            fatalError("La prueba de limpieza no se completó")
        }
        print(message)

        // Los nombres con traversal se bloquean antes de crear archivos.
        do {
            _ = try NXOwnedTemporaryWorkspaces.create(
                data: Data("no".utf8), optionID: UUID(), filename: "../../otra-ruta"
            )
            fatalError("No se bloqueó el nombre peligroso")
        } catch NXOwnedTemporaryWorkspaces.CleanupError.invalidFilename {
            print("Ruta no permitida: bloqueada correctamente.")
        }

        // Limpiar una opción dos veces debe ser seguro e independiente.
        let option = UUID()
        _ = try NXOwnedTemporaryWorkspaces.create(
            data: Data("a".utf8), optionID: option, filename: "a.tmp"
        )
        guard try NXOwnedTemporaryWorkspaces.clean(optionID: option) == 1,
              try NXOwnedTemporaryWorkspaces.clean(optionID: option) == 0,
              try NXOwnedTemporaryWorkspaces.isClean(optionID: option) else {
            fatalError("La limpieza idempotente falló")
        }
        print("Limpieza repetida: segura.")

        // Al iniciar, recuperar solo espacios antiguos, sin afectar uno reciente.
        let abandoned = UUID()
        let current = UUID()
        let oldFile = try NXOwnedTemporaryWorkspaces.create(
            data: Data("antiguo".utf8), optionID: abandoned, filename: "old.tmp"
        )
        let currentFile = try NXOwnedTemporaryWorkspaces.create(
            data: Data("reciente".utf8), optionID: current, filename: "current.tmp"
        )
        defer {
            _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: abandoned)
            _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: current)
        }
        let abandonedFolder = oldFile.deletingLastPathComponent()
        // La limpieza reforzada debe comprobar que TAMBIÉN los archivos sean antiguos.
        try fm.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -72 * 60 * 60)],
            ofItemAtPath: oldFile.path
        )
        try fm.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -72 * 60 * 60)],
            ofItemAtPath: abandonedFolder.path
        )
        let recovered = try NXOwnedTemporaryWorkspaces.cleanAbandoned(olderThan: 48 * 60 * 60)
        guard recovered >= 1,
              try NXOwnedTemporaryWorkspaces.isClean(optionID: abandoned),
              fm.fileExists(atPath: currentFile.path),
              try Data(contentsOf: currentFile) == Data("reciente".utf8) else {
            fatalError("La recuperación selectiva de temporales falló")
        }
        print("Temporales antiguos: eliminados; los recientes permanecen intactos.")

        // Un directorio de hace 72h con un archivo recién actualizado se conserva.
        let staleFolderRecentDataID = UUID()
        let recentPayload = Data("no tocar trabajo reciente".utf8)
        let recentPayloadURL = try NXOwnedTemporaryWorkspaces.create(
            data: recentPayload, optionID: staleFolderRecentDataID, filename: "updated.tmp"
        )
        defer { _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: staleFolderRecentDataID) }
        try fm.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -72 * 60 * 60)],
            ofItemAtPath: recentPayloadURL.deletingLastPathComponent().path
        )
        _ = try NXOwnedTemporaryWorkspaces.cleanAbandoned(olderThan: 48 * 60 * 60)
        guard fm.fileExists(atPath: recentPayloadURL.path),
              try Data(contentsOf: recentPayloadURL) == recentPayload else {
            fatalError("La limpieza borró un temporal reciente dentro de una carpeta antigua")
        }
        print("Archivo actualizado recientemente: conservado.")

        // Un directorio con copia de restauración pendiente no se toca.
        let protectedOption = UUID()
        let protectedURL = try NXOwnedTemporaryWorkspaces.create(
            data: Data("protegido".utf8), optionID: protectedOption, filename: "protected.tmp"
        )
        defer { _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: protectedOption) }
        let olderDate = Date(timeIntervalSinceNow: -72 * 60 * 60)
        try fm.setAttributes([.modificationDate: olderDate], ofItemAtPath: protectedURL.path)
        try fm.setAttributes([.modificationDate: olderDate], ofItemAtPath: protectedURL.deletingLastPathComponent().path)
        _ = try NXOwnedTemporaryWorkspaces.cleanAbandoned(
            olderThan: 48 * 60 * 60, keeping: [protectedOption]
        )
        guard fm.fileExists(atPath: protectedURL.path) else {
            fatalError("No se conservó el espacio protegido")
        }
        print("Espacio temporal protegido: conservado.")

        // No borrar enlaces simbólicos que aparenten ser directorios de opciones.
        let fakeOption = UUID()
        let root = currentFile.deletingLastPathComponent().deletingLastPathComponent()
        let trap = root.appendingPathComponent(fakeOption.uuidString)
        let outside = fm.temporaryDirectory.appendingPathComponent("nx-keep-\(UUID().uuidString)")
        try Data("NO BORRAR".utf8).write(to: outside)
        defer {
            try? fm.removeItem(at: trap)
            try? fm.removeItem(at: outside)
        }
        try fm.createSymbolicLink(at: trap, withDestinationURL: outside)
        _ = try NXOwnedTemporaryWorkspaces.cleanAbandoned(olderThan: 48 * 60 * 60)
        guard fm.fileExists(atPath: outside.path),
              try Data(contentsOf: outside) == Data("NO BORRAR".utf8) else {
            fatalError("La limpieza siguió un enlace simbólico")
        }
        print("Enlace simbólico externo: protegido.")
    }
}
