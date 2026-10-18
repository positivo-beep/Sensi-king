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

        // Limpieza manual de todos los espacios propios, preservando opciones
        // protegidas y sin tocar rutas externas ni enlaces simbólicos sospechosos.
        let toClearA = UUID()
        let toClearB = UUID()
        let protectedOption = UUID()
        _ = try NXOwnedTemporaryWorkspaces.create(
            data: Data("a".utf8), optionID: toClearA, filename: "a.tmp"
        )
        _ = try NXOwnedTemporaryWorkspaces.create(
            data: Data("b".utf8), optionID: toClearB, filename: "b.tmp"
        )
        let protectedFile = try NXOwnedTemporaryWorkspaces.create(
            data: Data("protegido".utf8), optionID: protectedOption, filename: "keep.tmp"
        )
        defer { _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: protectedOption) }
        let unknown = root.appendingPathComponent("not-an-option.txt")
        try Data("mantener".utf8).write(to: unknown, options: .atomic)
        defer { try? fm.removeItem(at: unknown) }
        let manual = try NXOwnedTemporaryWorkspaces.cleanAll(keeping: [protectedOption])
        guard manual.cleanedWorkspaces >= 2,
              manual.removedEntries >= 2,
              manual.protectedWorkspaces >= 1,
              try NXOwnedTemporaryWorkspaces.isClean(optionID: toClearA),
              try NXOwnedTemporaryWorkspaces.isClean(optionID: toClearB),
              fm.fileExists(atPath: protectedFile.path),
              try Data(contentsOf: protectedFile) == Data("protegido".utf8),
              fm.fileExists(atPath: outside.path),
              try Data(contentsOf: outside) == Data("NO BORRAR".utf8),
              manual.failedWorkspaces.contains(fakeOption.uuidString),
              manual.unrecognizedEntries >= 1,
              try Data(contentsOf: unknown) == Data("mantener".utf8),
              !manual.isComplete else {
            fatalError("La limpieza manual no distinguió correctamente los datos")
        }
        print("Limpieza manual: temporales propios borrados; protegidos y externos intactos; casos inseguros informados.")
        print("Entradas desconocidas: no eliminadas ni presentadas como éxito.")
    }
}
