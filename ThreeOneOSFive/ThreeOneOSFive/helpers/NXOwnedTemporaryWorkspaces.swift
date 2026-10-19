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
        // Nombres estrictamente ASCII y limitados en tamaño: no permitir rutas,
        // separadores, saltos de línea, controles ni nombres excesivos.
        let isSafeName = !filename.isEmpty && filename.utf8.count <= 128 &&
            filename != "." && filename != ".." && filename.utf8.allSatisfy { byte in
                (65...90).contains(byte) || (97...122).contains(byte) ||
                (48...57).contains(byte) || byte == 45 || byte == 46 || byte == 95
            }
        guard isSafeName else { throw CleanupError.invalidFilename }
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
        // Nunca borrar recursivamente un directorio o enlace no reconocido. Si
        // alguna otra función puso algo inesperado aquí, conservar todo y avisar.
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey]
        let entries = try manager.contentsOfDirectory(
            at: workspace, includingPropertiesForKeys: Array(resourceKeys), options: []
        )
        for entry in entries {
            let values = try entry.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  entry.standardizedFileURL.deletingLastPathComponent() == workspace else {
                throw CleanupError.unsafeWorkspace
            }
        }
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

    /// La fecha del directorio no indica si un archivo fue modificado hace poco.
    /// Para no borrar trabajos recientes, solo considera abandonado un espacio
    /// cuyos archivos directos también sean antiguos. Ante un enlace simbólico,
    /// subcarpeta inesperada o metadatos incompletos, conserva el espacio.
    private static func isOldEnoughToClean(_ workspace: URL, before cutoff: Date) throws -> Bool {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey
        ]
        let attributes = try workspace.resourceValues(forKeys: keys)
        guard attributes.isDirectory == true,
              attributes.isSymbolicLink != true,
              let modified = attributes.contentModificationDate,
              modified <= cutoff else {
            return false
        }
        let entries = try manager.contentsOfDirectory(
            at: workspace, includingPropertiesForKeys: Array(keys), options: []
        )
        for entry in entries {
            let values = try entry.resourceValues(forKeys: keys)
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  let entryModified = values.contentModificationDate,
                  entryModified <= cutoff else {
                return false
            }
        }
        return true
    }

    /// Elimina SOLO espacios temporales abandonados dentro del caché propio de NEXORA.
    /// Se usa al arrancar la app, no durante una operación activa. No inspecciona
    /// aplicaciones externas ni respaldos/transacciones. Conserva temporales recientes.
    @discardableResult
    static func cleanAbandoned(olderThan minimumAge: TimeInterval = 48 * 60 * 60,
                               now: Date = Date(),
                               keeping protectedIDs: Set<UUID> = []) throws -> Int {
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
            // Igual que en limpieza manual: un espacio con restauración pendiente
            // NUNCA se borra automáticamente, aunque sea antiguo.
            guard !protectedIDs.contains(identifier) else { continue }
            // Verificar también las fechas de los archivos. Un archivo modificado
            // hoy no debe desaparecer solo porque el directorio es antiguo.
            // Un espacio inseguro no debe impedir que se revisen los demás.
            // Se conserva el problemático, sin suprimir detalles de la limpieza manual.
            do {
                guard try isOldEnoughToClean(candidate, before: now.addingTimeInterval(-minimumAge)) else {
                    continue
                }
                // clean vuelve a validar las entradas antes de cualquier borrado.
                _ = try clean(optionID: identifier)
                cleaned += 1
            } catch {
                continue
            }
        }
        return cleaned
    }

    /// Resultado de una limpieza solicitada explícitamente por el usuario.
    /// Los pendientes NO se anuncian como éxito. Esta operación no toca
    /// respaldos, claves, registros ni archivos externos al contenedor de NEXORA.
    struct CleanupReport {
        let cleanedWorkspaces: Int
        let removedEntries: Int
        let protectedWorkspaces: Int
        let failedWorkspaces: [String]
        let unrecognizedEntries: Int

        var isComplete: Bool {
            failedWorkspaces.isEmpty && unrecognizedEntries == 0 && protectedWorkspaces == 0
        }
    }

    /// Enumeración segura de identificadores para comprobar las restauraciones
    /// pendientes incluso cuando un paquete se quitó del catálogo de la interfaz.
    static func knownWorkspaceIDs() throws -> Set<UUID> {
        let base = try checkedRoot(create: false)
        guard manager.fileExists(atPath: base.path) else { return [] }
        let names = try manager.contentsOfDirectory(atPath: base.path)
        return Set(names.compactMap { name in
            guard let identifier = UUID(uuidString: name),
                  name.uppercased() == identifier.uuidString else { return nil }
            return identifier
        })
    }

    /// Limpia los espacios de trabajo temporales propios conocidos por UUID.
    /// Permite preservar explícitamente opciones activas. No borra carpetas
    /// desconocidas ni intenta seguir enlaces simbólicos.
    static func cleanAll(keeping protectedIDs: Set<UUID> = []) throws -> CleanupReport {
        let base = try checkedRoot(create: false)
        guard manager.fileExists(atPath: base.path) else {
            return CleanupReport(cleanedWorkspaces: 0, removedEntries: 0,
                                 protectedWorkspaces: 0, failedWorkspaces: [],
                                 unrecognizedEntries: 0)
        }
        let candidates = try manager.contentsOfDirectory(
            at: base, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey], options: []
        )
        var cleaned = 0
        var removed = 0
        var protected = 0
        var failed: [String] = []
        var unknown = 0

        for candidate in candidates {
            let name = candidate.lastPathComponent
            guard let identifier = UUID(uuidString: name),
                  name.uppercased() == identifier.uuidString,
                  candidate.standardizedFileURL.deletingLastPathComponent() == base else {
                unknown += 1
                continue
            }
            if protectedIDs.contains(identifier) {
                protected += 1
                continue
            }
            do {
                // clean vuelve a comprobar que la ruta no sea un enlace simbólico.
                let count = try clean(optionID: identifier)
                guard try isClean(optionID: identifier) else {
                    throw CleanupError.verificationFailed
                }
                removed += count
                cleaned += 1
            } catch {
                failed.append(identifier.uuidString)
            }
        }
        return CleanupReport(cleanedWorkspaces: cleaned, removedEntries: removed,
                             protectedWorkspaces: protected, failedWorkspaces: failed,
                             unrecognizedEntries: unknown)
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
