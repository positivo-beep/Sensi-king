import Foundation

/// Temporales generados por NEXORA, exclusivamente dentro de su propio contenedor.
/// Esta herramienta NO borra diarios de transacciones, copias de seguridad,
/// registros del sistema ni datos de otras aplicaciones.
enum NXOwnedTemporaryWorkspaces {
    enum CleanupError: LocalizedError {
        case invalidFilename
        case unsafeWorkspace
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .invalidFilename: return "Nombre de temporal no permitido."
            case .unsafeWorkspace: return "La carpeta temporal de NEXORA no es segura."
            case .verificationFailed: return "No fue posible verificar la limpieza de temporales."
            }
        }
    }

    private static let manager = FileManager.default

    private static var root: URL {
        let caches = manager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? manager.temporaryDirectory
        return caches.appendingPathComponent("NEXORA-OwnedTemporaryWorkspaces", isDirectory: true)
    }

    private static func checkedRoot(create: Bool) throws -> URL {
        let base = root.standardizedFileURL
        if manager.fileExists(atPath: base.path) {
            let flags = try base.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard flags.isDirectory == true && flags.isSymbolicLink != true else {
                throw CleanupError.unsafeWorkspace
            }
        } else if create {
            try manager.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }

    private static func path(for optionID: UUID, create: Bool) throws -> URL {
        let base = try checkedRoot(create: create)
        let workspace = base.appendingPathComponent(optionID.uuidString, isDirectory: true)
        guard workspace.standardizedFileURL.deletingLastPathComponent() == base else {
            throw CleanupError.unsafeWorkspace
        }
        if manager.fileExists(atPath: workspace.path) {
            let flags = try workspace.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard flags.isDirectory == true && flags.isSymbolicLink != true else {
                throw CleanupError.unsafeWorkspace
            }
        } else if create {
            try manager.createDirectory(at: workspace, withIntermediateDirectories: false)
        }
        return workspace
    }

    /// Crea SOLO un temporal propio, identificado por la opción que lo generó.
    @discardableResult
    static func create(data: Data, optionID: UUID, filename: String) throws -> URL {
        guard !filename.isEmpty, filename != ".", filename != "..",
              !filename.contains("/"), !filename.contains("\\"),
              filename.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
            throw CleanupError.invalidFilename
        }
        let workspace = try path(for: optionID, create: true)
        let target = workspace.appendingPathComponent(filename, isDirectory: false)
        if manager.fileExists(atPath: target.path) {
            // Nunca sobrescribir un temporal ajeno ni seguir un enlace simbólico.
            throw CleanupError.unsafeWorkspace
        }
        try data.write(to: target, options: [.atomic])
        return target
    }

    /// Borra SOLO el área de temporales de una opción, sin acceder a otra aplicación.
    @discardableResult
    static func clean(optionID: UUID) throws -> Int {
        let workspace = try path(for: optionID, create: false)
        guard manager.fileExists(atPath: workspace.path) else { return 0 }
        let entries = try manager.contentsOfDirectory(at: workspace, includingPropertiesForKeys: nil)
        try manager.removeItem(at: workspace)
        guard !manager.fileExists(atPath: workspace.path) else {
            throw CleanupError.verificationFailed
        }
        return entries.count
    }

    static func isClean(optionID: UUID) throws -> Bool {
        let workspace = try path(for: optionID, create: false)
        return !manager.fileExists(atPath: workspace.path)
    }

    /// Elimina SOLO espacios temporales abandonados dentro del caché propio de NEXORA.
    /// Se usa al arrancar la app, no durante una operación activa. No inspecciona
    /// aplicaciones externas ni respaldos/transacciones. Conserva temporales recientes.
    @discardableResult
    static func cleanAbandoned(olderThan minimumAge: TimeInterval = 48 * 60 * 60,
                               now: Date = Date()) throws -> Int {
        guard minimumAge > 0 else { return 0 }
        let base = try checkedRoot(create: false)
        guard manager.fileExists(atPath: base.path) else { return 0 }
        let candidates = try manager.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: []
        )
        var cleaned = 0
        for candidate in candidates {
            // Solo directorios propios nombrados por UUID y contenidos en nuestra raíz.
            guard let identifier = UUID(uuidString: candidate.lastPathComponent),
                  candidate.lastPathComponent.uppercased() == identifier.uuidString,
                  candidate.standardizedFileURL.deletingLastPathComponent() == base else {
                continue
            }
            let values = try candidate.resourceValues(forKeys: [
                .isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey
            ])
            guard values.isDirectory == true,
                  values.isSymbolicLink != true,
                  let modified = values.contentModificationDate,
                  now.timeIntervalSince(modified) >= minimumAge else {
                continue
            }
            // La propia clean vuelve a verificar la ruta y confirma la eliminación.
            _ = try clean(optionID: identifier)
            cleaned += 1
        }
        return cleaned
    }

    /// Prueba local: elimina los temporales de una opción y confirma que otra
    /// conserva los suyos hasta que se limpie explícitamente. No usa archivos externos.
    static func selfTest() throws -> String {
        let optionA = UUID()
        let optionB = UUID()
        let expectedB = Data("temporal de la opción B".utf8)
        defer {
            _ = try? clean(optionID: optionA)
            _ = try? clean(optionID: optionB)
        }
        _ = try create(data: Data("temporal de la opción A".utf8),
                       optionID: optionA, filename: "prueba-a.tmp")
        let fileB = try create(data: expectedB, optionID: optionB, filename: "prueba-b.tmp")
        let removedA = try clean(optionID: optionA)
        guard removedA == 1, try isClean(optionID: optionA),
              try Data(contentsOf: fileB) == expectedB else {
            throw CleanupError.verificationFailed
        }
        let removedB = try clean(optionID: optionB)
        guard removedB == 1, try isClean(optionID: optionB) else {
            throw CleanupError.verificationFailed
        }
        return "Limpieza OK: 2 temporales propios eliminados; cada opción se verificó por separado."
    }
}
