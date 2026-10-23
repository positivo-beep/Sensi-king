import Foundation

/// Historial de revisiones observadas en archivos a los que NEXORA ya tiene acceso.
/// Las revisiones son INMUTABLES y NO se consideran originales oficiales por
/// el simple hecho de haberse observado un cambio. Nunca modifica el destino.
/// El SHA-256 real se obtiene del motor de transacciones (CryptoKit).
enum NXOriginalRevisionLedger {
    enum Source: String, Codable {
        case initialObservation
        case externalChange
        case restorePreservedExternalChange
    }

    struct Revision: Codable {
        let schemaVersion: Int
        let targetDescription: String
        let sha256: String
        let byteCount: UInt64
        let observedAt: Date
        let source: Source
        // Una observación no prueba procedencia o compatibilidad del archivo.
        let provenanceVerified: Bool
    }

    enum LedgerError: LocalizedError {
        case invalidIdentity, changedWhileCopying, corruptedRevision, unsupportedFile
        var errorDescription: String? {
            switch self {
            case .invalidIdentity: return "Identidad inválida del archivo observado."
            case .changedWhileCopying: return "El archivo cambió durante el respaldo; no se registró como versión estable."
            case .corruptedRevision: return "Un respaldo de versión existente no supera la verificación."
            case .unsupportedFile: return "No se puede respaldar una ruta, enlace o archivo de ese tamaño."
            }
        }
    }

    private static let maximumBytes: UInt64 = 128 * 1024 * 1024

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private static func validDigest(_ value: Data) -> Bool { value.count == 32 }

    private static func assertRegularFile(_ url: URL, fileManager: FileManager) throws -> UInt64 {
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
        guard values.isSymbolicLink != true,
              values.isRegularFile == true,
              let rawSize = values.fileSize, rawSize > 0,
              UInt64(rawSize) <= maximumBytes else { throw LedgerError.unsupportedFile }
        return UInt64(rawSize)
    }

    /// `logicalKeySHA256` identifica bundleID + ruta lógica, nunca una ruta
    /// controlada por el servidor. `expectedDigest` es el hash SHA-256 del archivo
    /// leído. Copia a un área aislada y revalida el origen tras copiarlo.
    /// Devuelve true solo cuando se agregó una revisión nueva y completa.
    @discardableResult
    static func preserveIfNew(
        sourceURL: URL,
        backupRoot: URL,
        logicalKeySHA256: Data,
        targetDescription: String,
        expectedDigest: Data,
        reason: Source,
        digestFile: (URL) throws -> Data,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard validDigest(logicalKeySHA256), validDigest(expectedDigest),
              !targetDescription.isEmpty, targetDescription.utf8.count <= 1024 else {
            throw LedgerError.invalidIdentity
        }
        let originalSize = try assertRegularFile(sourceURL, fileManager: fileManager)
        guard try digestFile(sourceURL) == expectedDigest else {
            throw LedgerError.changedWhileCopying
        }

        let root = backupRoot.appendingPathComponent("_OriginalRevisions", isDirectory: true)
            .appendingPathComponent(hex(logicalKeySHA256), isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let final = root.appendingPathComponent(hex(expectedDigest), isDirectory: true)
        let storedFile = final.appendingPathComponent("observed-original.bin")
        let metadataURL = final.appendingPathComponent("revision.json")

        if fileManager.fileExists(atPath: final.path) {
            guard let stored = try? JSONDecoder().decode(Revision.self, from: Data(contentsOf: metadataURL)),
                  stored.schemaVersion == 1,
                  stored.sha256 == hex(expectedDigest),
                  stored.targetDescription == targetDescription,
                  stored.byteCount == originalSize,
                  (try? digestFile(storedFile)) == expectedDigest else {
                throw LedgerError.corruptedRevision
            }
            return false
        }

        let stage = root.appendingPathComponent(".pending-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: stage) }
        let stagedCopy = stage.appendingPathComponent("observed-original.bin")
        try fileManager.copyItem(at: sourceURL, to: stagedCopy)
        guard try assertRegularFile(stagedCopy, fileManager: fileManager) == originalSize,
              try digestFile(stagedCopy) == expectedDigest,
              try digestFile(sourceURL) == expectedDigest else {
            throw LedgerError.changedWhileCopying
        }
        let record = Revision(
            schemaVersion: 1,
            targetDescription: targetDescription,
            sha256: hex(expectedDigest),
            byteCount: originalSize,
            observedAt: Date(),
            source: reason,
            provenanceVerified: false
        )
        try JSONEncoder().encode(record).write(
            to: stage.appendingPathComponent("revision.json"), options: .atomic
        )
        // Publicar el archivo y sus metadatos como una sola carpeta completa.
        // Jamás reemplazar revisiones anteriores.
        if fileManager.fileExists(atPath: final.path) { return false }
        try fileManager.moveItem(at: stage, to: final)
        return true
    }
}
