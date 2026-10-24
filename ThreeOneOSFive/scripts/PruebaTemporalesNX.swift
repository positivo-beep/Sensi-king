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
        let abandonedDate = Date(timeIntervalSinceNow: -72 * 60 * 60)
        try fm.setAttributes([.modificationDate: abandonedDate], ofItemAtPath: oldFile.path)
        try fm.setAttributes([.modificationDate: abandonedDate], ofItemAtPath: abandonedFolder.path)
        let recovered = try NXOwnedTemporaryWorkspaces.cleanAbandoned(olderThan: 48 * 60 * 60)
        guard recovered >= 1,
              try NXOwnedTemporaryWorkspaces.isClean(optionID: abandoned),
              fm.fileExists(atPath: currentFile.path),
              try Data(contentsOf: currentFile) == Data("reciente".utf8) else {
            fatalError("La recuperación selectiva de temporales falló")
        }
        print("Temporales antiguos: eliminados; los recientes permanecen intactos.")

        // Un directorio antiguo puede contener un archivo modificado recientemente.
        // Esta condición debe impedir la limpieza automática.
        let recentContents = UUID()
        let recentContentsFile = try NXOwnedTemporaryWorkspaces.create(
            data: Data("activo".utf8), optionID: recentContents, filename: "active.tmp"
        )
        defer { _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: recentContents) }
        let oldFolder = recentContentsFile.deletingLastPathComponent()
        try fm.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -96 * 60 * 60)],
            ofItemAtPath: oldFolder.path
        )
        _ = try NXOwnedTemporaryWorkspaces.cleanAbandoned(olderThan: 48 * 60 * 60)
        guard fm.fileExists(atPath: recentContentsFile.path),
              try Data(contentsOf: recentContentsFile) == Data("activo".utf8) else {
            fatalError("Un temporal reciente desapareció por la antigüedad de su carpeta")
        }
        print("Contenido reciente: protegido aunque la carpeta sea antigua.")

        // Un respaldo conservado por NEXORA debe impedir la eliminación
        // automática del espacio temporal de su proyecto. La limpieza de
        // proyectos sin respaldo sí continúa con su antigüedad habitual.
        let protectedByBackup = UUID()
        let disposable = UUID()
        let fileWithBackup = try NXOwnedTemporaryWorkspaces.create(
            data: Data("temporal respaldado".utf8),
            optionID: protectedByBackup, filename: "protected.tmp"
        )
        let disposableFile = try NXOwnedTemporaryWorkspaces.create(
            data: Data("temporal desechable".utf8),
            optionID: disposable, filename: "disposable.tmp"
        )
        defer {
            _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: protectedByBackup)
            _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: disposable)
        }
        for file in [fileWithBackup, disposableFile] {
            let old = Date(timeIntervalSinceNow: -80 * 60 * 60)
            try fm.setAttributes([.modificationDate: old], ofItemAtPath: file.path)
            try fm.setAttributes([.modificationDate: old], ofItemAtPath: file.deletingLastPathComponent().path)
        }
        let backupFixture = fm.temporaryDirectory.appendingPathComponent("nexora-backups-test-\(UUID().uuidString)")
        try fm.createDirectory(at: backupFixture, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: backupFixture) }
        try fm.createDirectory(
            at: backupFixture.appendingPathComponent(protectedByBackup.uuidString),
            withIntermediateDirectories: false
        )
        let safeIDs = try NXOwnedTemporaryWorkspaces.protectedWorkspaceIDs(
            knownIDs: [protectedByBackup, disposable], backupRoot: backupFixture
        )
        guard safeIDs == [protectedByBackup] else { fatalError("No se identificó el respaldo") }
        _ = try NXOwnedTemporaryWorkspaces.cleanAbandoned(
            olderThan: 48 * 60 * 60, keeping: safeIDs
        )
        guard fm.fileExists(atPath: fileWithBackup.path),
              try NXOwnedTemporaryWorkspaces.isClean(optionID: disposable) else {
            fatalError("La limpieza no respetó el respaldo o no limpió el temporal desechable")
        }
        print("Limpieza automática: respaldos protegidos y temporales propios vencidos retirados.")

        // Una restauración pendiente debe prevalecer sobre la antigüedad.
        let pendingRestore = UUID()
        let protectedData = Data("respaldo pendiente: conservar temporal".utf8)
        let pendingFile = try NXOwnedTemporaryWorkspaces.create(
            data: protectedData, optionID: pendingRestore, filename: "pending.tmp"
        )
        defer { _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: pendingRestore) }
        let pendingDate = Date(timeIntervalSinceNow: -96 * 60 * 60)
        try fm.setAttributes([.modificationDate: pendingDate], ofItemAtPath: pendingFile.path)
        try fm.setAttributes([.modificationDate: pendingDate],
                             ofItemAtPath: pendingFile.deletingLastPathComponent().path)
        _ = try NXOwnedTemporaryWorkspaces.cleanAbandoned(
            olderThan: 48 * 60 * 60, keeping: [pendingRestore]
        )
        guard fm.fileExists(atPath: pendingFile.path),
              try Data(contentsOf: pendingFile) == protectedData else {
            fatalError("La limpieza automática borró un temporal protegido")
        }
        print("Restauración pendiente: espacio antiguo protegido en limpieza automática.")


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

        // No aceptar temporales con saltos de línea, controles o nombres enormes.
        for badName in ["archivo.tmp\n", "tab\t.tmp", String(repeating: "a", count: 129)] {
            do {
                _ = try NXOwnedTemporaryWorkspaces.create(
                    data: Data("rechazar".utf8), optionID: UUID(), filename: badName
                )
                fatalError("Se admitió un nombre temporal no permitido")
            } catch NXOwnedTemporaryWorkspaces.CleanupError.invalidFilename {
                // Resultado esperado.
            }
        }
        print("Nombres no seguros y nombres largos: rechazados.")

        // Un enlace dentro de una carpeta propia NO autoriza borrado recursivo.
        let suspicious = UUID()
        let safeFile = try NXOwnedTemporaryWorkspaces.create(
            data: Data("conservar".utf8), optionID: suspicious, filename: "safe.tmp"
        )
        let linkedFile = safeFile.deletingLastPathComponent().appendingPathComponent("external-link.tmp")
        try fm.createSymbolicLink(at: linkedFile, withDestinationURL: outside)
        do {
            _ = try NXOwnedTemporaryWorkspaces.clean(optionID: suspicious)
            fatalError("Se eliminó recursivamente un espacio con enlace inesperado")
        } catch NXOwnedTemporaryWorkspaces.CleanupError.unsafeWorkspace {
            guard fm.fileExists(atPath: safeFile.path),
                  try Data(contentsOf: safeFile) == Data("conservar".utf8),
                  try Data(contentsOf: outside) == Data("NO BORRAR".utf8) else {
                fatalError("Se modificó contenido de un espacio inseguro")
            }
        }
        try fm.removeItem(at: linkedFile)
        _ = try NXOwnedTemporaryWorkspaces.clean(optionID: suspicious)
        print("Enlace inesperado dentro de temporal: borrado bloqueado.")

        // Una subcarpeta desconocida tampoco se borra con sus archivos.
        let nested = UUID()
        let nestedFile = try NXOwnedTemporaryWorkspaces.create(
            data: Data("original".utf8), optionID: nested, filename: "normal.tmp"
        )
        let foreignFolder = nestedFile.deletingLastPathComponent().appendingPathComponent("foreign")
        try fm.createDirectory(at: foreignFolder, withIntermediateDirectories: false)
        let foreignFile = foreignFolder.appendingPathComponent("important.dat")
        try Data("protegido".utf8).write(to: foreignFile)
        do {
            _ = try NXOwnedTemporaryWorkspaces.clean(optionID: nested)
            fatalError("Se borró un directorio desconocido")
        } catch NXOwnedTemporaryWorkspaces.CleanupError.unsafeWorkspace {
            guard try Data(contentsOf: foreignFile) == Data("protegido".utf8) else {
                fatalError("Se borraron archivos de un subdirectorio desconocido")
            }
        }
        try fm.removeItem(at: foreignFolder)
        _ = try NXOwnedTemporaryWorkspaces.clean(optionID: nested)
        print("Subcarpeta inesperada: conservada y reportada.")
    }
}
