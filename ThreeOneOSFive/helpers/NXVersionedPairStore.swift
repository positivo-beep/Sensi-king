import CryptoKit
import Foundation

// Versiones de originales y variantes administradas por NEXORA dentro de SU sandbox.
// No accede a contenedores de aplicaciones ajenas. El digest completo vincula
// cada variante a la versión exacta de su original (cualquier byte distinto bloquea).
struct NXPairRemoteFile: Decodable {
    let url: String
    let sha256: String
    let bytes: Int
}

struct NXCompatibleResourcePair: Decodable {
    let id: String
    let revision: Int
    let original: NXPairRemoteFile
    let modified: NXPairRemoteFile
    let modifiedForOriginalSHA256: String
}

private struct NXInstalledPair: Codable {
    let revision: Int
    let originalSHA256: String
    let modifiedSHA256: String
    let originalBytes: Int
    let modifiedBytes: Int
    let versionFolder: String
}

enum NXPairFailure: LocalizedError {
    case invalidPair, notInstalled, originalChanged, modifiedChanged, insufficientStorage
    var errorDescription: String? {
        switch self {
        case .invalidPair: return "No existe una pareja válida para esta versión original. No se modificó nada."
        case .notInstalled: return "No hay una variante compatible descargada y verificada."
        case .originalChanged: return "El archivo original ha cambiado, aunque sea un solo byte. Se bloqueó la variante anterior para evitar incompatibilidad."
        case .modifiedChanged: return "La variante descargada fue modificada o está dañada. Se bloqueó su activación."
        case .insufficientStorage: return "No hay espacio suficiente para conservar la versión anterior."
        }
    }
}

enum NXVersionedPairStore {
    private static let maximumFileBytes = 8 * 1024 * 1024
    private static let directoryName = "CompatiblePairs"

    static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 64 && id.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) ||
            (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }

    static func validHash(_ hash: String) -> Bool {
        hash.utf8.count == 64 && hash.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    static func validate(_ pair: NXCompatibleResourcePair) throws {
        guard validID(pair.id), pair.revision > 0,
              pair.original.bytes > 0, pair.original.bytes <= maximumFileBytes,
              pair.modified.bytes > 0, pair.modified.bytes <= maximumFileBytes,
              validHash(pair.original.sha256), validHash(pair.modified.sha256),
              validHash(pair.modifiedForOriginalSHA256),
              pair.modifiedForOriginalSHA256 == pair.original.sha256 else {
            throw NXPairFailure.invalidPair
        }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func root() throws -> URL {
        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let url = appSupport.appendingPathComponent("NexoraOwnedResources", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func indexURL(_ base: URL) -> URL {
        base.appendingPathComponent("pairs-index.json", isDirectory: false)
    }

    private static func index(_ base: URL) throws -> [String: NXInstalledPair] {
        let url = indexURL(base)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let value = try JSONDecoder().decode([String: NXInstalledPair].self, from: Data(contentsOf: url))
        // No usar nombres provenientes de un índice corrompido para salir del sandbox.
        guard value.allSatisfy({ validID($0.key) && validID($0.value.versionFolder) }) else {
            throw NXPairFailure.invalidPair
        }
        return value
    }

    private static func files(_ pair: NXInstalledPair, in base: URL) -> (URL, URL) {
        let dir = base.appendingPathComponent("versions", isDirectory: true)
            .appendingPathComponent(pair.versionFolder, isDirectory: true)
        return (dir.appendingPathComponent("original.dat"), dir.appendingPathComponent("modified.dat"))
    }

    static func installedCount() -> Int {
        guard let base = try? root(), let saved = try? index(base) else { return 0 }
        return saved.count
    }

    static func needsUpdate(_ remote: NXCompatibleResourcePair) -> Bool {
        guard let base = try? root(),
              let records = try? index(base),
              let current = records[remote.id] else { return true }
        // Una revisión anterior o un archivo local alterado exige revisión.
        if current.revision < remote.revision { return true }
        if current.revision > remote.revision { return false } // Nunca degradar.
        if current.originalSHA256 != remote.original.sha256 ||
           current.modifiedSHA256 != remote.modified.sha256 { return true }
        // No "reparar" automáticamente un original alterado bajando la versión.
        // El bloqueo permanece hasta recibir una pareja con revisión superior.
        return false
    }

    // Solo se llama con los dos ficheros YA descargados desde HTTPS y comprobados.
    // Primero escribimos una pareja inmutable; solamente al final se activa su índice.
    // Si la app se cierra a mitad, el índice antiguo y su copia siguen intactos.
    static func install(_ remote: NXCompatibleResourcePair,
                        original: Data, modified: Data) throws {
        try validate(remote)
        guard original.count == remote.original.bytes,
              modified.count == remote.modified.bytes,
              sha256(original) == remote.original.sha256,
              sha256(modified) == remote.modified.sha256 else {
            throw NXPairFailure.invalidPair
        }
        let base = try root()
        var saved = try index(base)
        if let previous = saved[remote.id] {
            guard remote.revision >= previous.revision else { throw NXPairFailure.invalidPair }
            // No permitir que un catálogo reescriba silenciosamente una revisión.
            if remote.revision == previous.revision &&
                (remote.original.sha256 != previous.originalSHA256 ||
                 remote.modified.sha256 != previous.modifiedSHA256) {
                throw NXPairFailure.invalidPair
            }
        }
        let fm = FileManager.default
        let versions = base.appendingPathComponent("versions", isDirectory: true)
        try fm.createDirectory(at: versions, withIntermediateDirectories: true)
        let ident = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let stage = base.appendingPathComponent(".stage-\(ident)", isDirectory: true)
        let final = versions.appendingPathComponent(ident, isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: stage) }
        try original.write(to: stage.appendingPathComponent("original.dat"), options: .atomic)
        try modified.write(to: stage.appendingPathComponent("modified.dat"), options: .atomic)
        // Verificación de lectura real antes de publicar la versión.
        guard sha256(try Data(contentsOf: stage.appendingPathComponent("original.dat"))) == remote.original.sha256,
              sha256(try Data(contentsOf: stage.appendingPathComponent("modified.dat"))) == remote.modified.sha256 else {
            throw NXPairFailure.invalidPair
        }
        try fm.moveItem(at: stage, to: final)
        let next = NXInstalledPair(revision: remote.revision,
            originalSHA256: remote.original.sha256,
            modifiedSHA256: remote.modified.sha256,
            originalBytes: remote.original.bytes,
            modifiedBytes: remote.modified.bytes,
            versionFolder: ident)
        saved[remote.id] = next
        // Atomic: solo el índice apunta a la nueva pareja cuando los dos existen.
        try JSONEncoder().encode(saved).write(to: indexURL(base), options: .atomic)
        // NO eliminar versiones anteriores: permiten recuperar originales previos.
    }

    private static func checkedData(from url: URL, expectedSize: Int) throws -> Data {
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey]
        let metadata = try url.resourceValues(forKeys: keys)
        guard metadata.isSymbolicLink != true,
              metadata.isRegularFile == true,
              metadata.fileSize == expectedSize,
              expectedSize > 0, expectedSize <= maximumFileBytes else {
            throw NXPairFailure.invalidPair
        }
        return try Data(contentsOf: url)
    }

    private static func verifiedURLs(id: String) throws -> (original: URL, modified: URL) {
        guard validID(id) else { throw NXPairFailure.invalidPair }
        let base = try root()
        guard let entry = try index(base)[id] else { throw NXPairFailure.notInstalled }
        let (originalURL, modifiedURL) = files(entry, in: base)
        let original = try checkedData(from: originalURL, expectedSize: entry.originalBytes)
        guard original.count == entry.originalBytes,
              original.count <= maximumFileBytes,
              sha256(original) == entry.originalSHA256 else { throw NXPairFailure.originalChanged }
        let modified = try checkedData(from: modifiedURL, expectedSize: entry.modifiedBytes)
        guard modified.count == entry.modifiedBytes,
              modified.count <= maximumFileBytes,
              sha256(modified) == entry.modifiedSHA256 else { throw NXPairFailure.modifiedChanged }
        return (originalURL, modifiedURL)
    }

    // Conecta las parejas de versiones con un recurso que otra capa obtuvo
    // mediante acceso autorizado. No resuelve contenedores ni rutas ajenas.
    // Solo devuelve una variante cuando el original EN DISCO coincide con
    // el SHA-256 de la pareja publicada para este identificador real.
    static func compatibleVariant(id: String, originalURL: URL) throws ->
        (data: Data, originalDigest: Data)? {
        guard validID(id) else { throw NXPairFailure.invalidPair }
        let base = try root()
        guard let registered = try index(base)[id] else { return nil }
        let urls = try verifiedURLs(id: id)
        let attributes = try originalURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard attributes.isRegularFile == true,
              attributes.isSymbolicLink != true,
              attributes.fileSize == registered.originalBytes else {
            throw NXPairFailure.originalChanged
        }
        let current = try Data(contentsOf: originalURL, options: .mappedIfSafe)
        guard current.count == registered.originalBytes,
              sha256(current) == registered.originalSHA256 else {
            throw NXPairFailure.originalChanged
        }
        let replacement = try checkedData(from: urls.modified, expectedSize: registered.modifiedBytes)
        guard sha256(replacement) == registered.modifiedSHA256 else {
            throw NXPairFailure.modifiedChanged
        }
        return (replacement, Data(SHA256.hash(data: current)))
    }

    // ESTE método debe consultarse cada vez que se pretenda activar una variante.
    // Jamás devuelve la variante si el original cambió por un solo byte.
    static func validatedVariantURL(id: String) throws -> URL {
        try verifiedURLs(id: id).modified
    }

    static func validationSummary() -> String {
        do {
            let base = try root()
            let saved = try index(base)
            if saved.isEmpty { return "No hay originales ni variantes registrados todavía." }
            var valid = 0
            var invalid = 0
            for key in saved.keys {
                if (try? validatedVariantURL(id: key)) != nil { valid += 1 }
                else { invalid += 1 }
            }
            return invalid == 0
                ? "\(valid) pareja(s) original/variante compatibles y verificadas byte por byte."
                : "\(invalid) pareja(s) con cambios o corrupción: activación bloqueada; \(valid) compatibles."
        } catch {
            return "No se pudo verificar compatibilidad: \(error.localizedDescription)"
        }
    }

    // Demostración reversible: activa solo un recurso PROPIO, nunca un juego externo.
    static func activateOwnedPair(id: String) throws {
        let verified = try verifiedURLs(id: id)
        let base = try root()
        let active = base.appendingPathComponent("activated", isDirectory: true)
        try FileManager.default.createDirectory(at: active, withIntermediateDirectories: true)
        let bytes = try Data(contentsOf: verified.modified)
        let destination = active.appendingPathComponent("\(id).dat")
        try bytes.write(to: destination, options: .atomic)
        guard sha256(try Data(contentsOf: destination)) == sha256(bytes) else {
            throw NXPairFailure.modifiedChanged
        }
    }

    static func restoreOwnedPair(id: String) throws {
        let verified = try verifiedURLs(id: id)
        let base = try root()
        let active = base.appendingPathComponent("activated", isDirectory: true)
        try FileManager.default.createDirectory(at: active, withIntermediateDirectories: true)
        let bytes = try Data(contentsOf: verified.original)
        let destination = active.appendingPathComponent("\(id).dat")
        try bytes.write(to: destination, options: .atomic)
        guard sha256(try Data(contentsOf: destination)) == sha256(bytes) else {
            throw NXPairFailure.originalChanged
        }
    }
}
