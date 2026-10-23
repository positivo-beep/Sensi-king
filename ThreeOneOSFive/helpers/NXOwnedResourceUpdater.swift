import Combine
import CryptoKit
import Foundation

// Actualizador de recursos gestionados por NEXORA. No reemplaza el ejecutable,
// no abre contenedores de terceros y no altera transacciones de parches.
// Publicación firmada con Ed25519 por el dueño del catálogo NEXORA.
// SHA-256 prueba integridad; esta firma opcional prueba control de la clave fijada.
private struct NXSignedUpdateEnvelope: Decodable {
    let format: String
    let payloadBase64: String
    let signatureBase64: String
}

private struct NXUpdateManifest: Decodable {
    let schema: Int
    let resources: [NXRemoteResource]
    let compatiblePairs: [NXCompatibleResourcePair]?
}

private struct NXRemoteResource: Decodable {
    let id: String
    let revision: Int
    let file: String
    let url: String
    let sha256: String
    let bytes: Int
}

private struct NXUpdateJournal: Codable {
    let id: String
    let filename: String
    let revision: Int
    let hadPrevious: Bool
}

private struct NXInstalledResource: Codable {
    let revision: Int
    let sha256: String
    let file: String
}

private final class NXNoUpdateRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private enum NXUpdateFailure: LocalizedError {
    case invalidSource, invalidManifest, invalidResource, invalidResponse
    case tooLarge, digestMismatch, insufficientStorage, invalidSignature, unsignedManifest

    var errorDescription: String? {
        switch self {
        case .invalidSource: return "Configura una URL HTTPS válida para actualizaciones de NEXORA."
        case .invalidManifest: return "El catálogo de actualización tiene un formato inválido."
        case .invalidResource: return "El catálogo contiene un recurso o ruta no permitida."
        case .invalidResponse: return "El servidor no devolvió una respuesta válida (HTTP 200)."
        case .tooLarge: return "El catálogo o archivo excede los límites de tamaño."
        case .digestMismatch: return "La verificación SHA-256 falló. No se instaló el archivo."
        case .insufficientStorage: return "No hay espacio suficiente para respaldar y actualizar."
        case .invalidSignature: return "No se pudo verificar la firma Ed25519 del catálogo. No se instaló nada."
        case .unsignedManifest: return "El catálogo no está firmado por la clave pública configurada. No se instaló nada."
        }
    }
}

@MainActor
final class NXOwnedResourceUpdater: ObservableObject {
    @Published private(set) var isBusy = false
    @Published private(set) var status = "Actualizaciones sin configurar"
    @Published private(set) var installedCount = 0
    @Published private(set) var releaseNotes = ""
    @Published private(set) var compatiblePairsCount = 0
    @Published private(set) var compatibilityStatus = "No hay parejas original/variante verificadas"
    @Published private(set) var demoStatus = "Prueba local sin ejecutar"
    @Published private(set) var provenanceStatus = "Sin comprobar el origen del catálogo"
    @Published var trustedSigningKeyInput: String {
        didSet { defaults.set(trustedSigningKeyInput, forKey: Self.signingKeySetting) }
    }
    @Published var autoEnabled: Bool {
        didSet { defaults.set(autoEnabled, forKey: Self.autoKey) }
    }
    @Published var manifestInput: String {
        didSet { defaults.set(manifestInput, forKey: Self.manifestKey) }
    }

    private static let autoKey = "nexora.ownedupdates.enabled.v1"
    private static let manifestKey = "nexora.ownedupdates.manifest.v1"
    private static let signingKeySetting = "nexora.ownedupdates.public-signing-key.v1"
    private static let lastCheckKey = "nexora.ownedupdates.lastcheck.v1"
    private static let minimumCheckInterval: TimeInterval = 12 * 60 * 60
    private static let maximumManifestSize = 128 * 1024
    private static let maximumResourceSize = 8 * 1024 * 1024
    private static let maximumTotalSize = 48 * 1024 * 1024

    private let defaults: UserDefaults
    private let session: URLSession
    private let fileManager = FileManager.default

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoEnabled = defaults.bool(forKey: Self.autoKey)
        manifestInput = defaults.string(forKey: Self.manifestKey) ?? ""
        trustedSigningKeyInput = defaults.string(forKey: Self.signingKeySetting) ?? ""
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 45
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.httpMaximumConnectionsPerHost = 2
        session = URLSession(configuration: config, delegate: NXNoUpdateRedirects(), delegateQueue: nil)
        if let root = try? Self.resourceDirectory() {
            Self.recoverInterruptedTransactions(at: root)
        }
        installedCount = ((try? Self.loadInstalled(at: Self.receiptURL())) ?? [:]).count
        releaseNotes = Self.readReleaseNotes()
        compatiblePairsCount = NXVersionedPairStore.installedCount()
        compatibilityStatus = NXVersionedPairStore.validationSummary()
        if !manifestInput.isEmpty {
            status = "Listo para buscar actualizaciones de recursos propios"
        }
    }

    func checkWhenActive() {
        guard autoEnabled, !isBusy else { return }
        let last = defaults.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= Self.minimumCheckInterval else { return }
        Task { await checkNow() }
    }

    func checkNow() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        status = "Comprobando catálogo de NEXORA…"

        do {
            let source = try Self.validatedHTTPSURL(manifestInput)
            let manifestData = try await fetch(source, limit: Self.maximumManifestSize)
            let (manifest, signed) = try Self.verifiedManifest(manifestData, publicKeyBase64: trustedSigningKeyInput)
            provenanceStatus = signed
                ? "Firma Ed25519 válida para la clave pública configurada de NEXORA. No acredita parches oficiales de otros desarrolladores."
                : "Catálogo sin firma verificable. Solo recursos propios; no se importarán parejas modificadas."
            guard manifest.schema == 1, manifest.resources.count <= 32,
                  (manifest.compatiblePairs?.count ?? 0) <= 32 else {
                throw NXUpdateFailure.invalidManifest
            }
            try Self.validate(manifest, from: source)
            // Fallar ANTES de instalar cualquier archivo de este catálogo.
            if !signed && !(manifest.compatiblePairs ?? []).isEmpty {
                throw NXUpdateFailure.unsignedManifest
            }

            // No pasar por rutas de aplicaciones ajenas ni por archivos del bundle.
            let directory = try Self.resourceDirectory()
            var installed = try Self.loadInstalled(at: Self.receiptURL())
            var changed = 0
            for entry in manifest.resources {
                if let old = installed[entry.id] {
                    if old.revision > entry.revision { continue }
                    if old.revision == entry.revision, Self.installedBytesMatch(old, at: directory) { continue }
                }
                status = "Descargando recurso \(entry.id)…"
                let remoteURL = try Self.resourceURL(entry, source: source)
                let bytes = try await fetch(remoteURL, limit: Self.maximumResourceSize)
                guard bytes.count == entry.bytes else { throw NXUpdateFailure.invalidResource }
                let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                guard digest == entry.sha256.lowercased() else { throw NXUpdateFailure.digestMismatch }
                // Escribe primero dentro de nuestro sandbox, y guarda el anterior
                // para restaurarlo si falla el intercambio o el recibo.
                try Self.install(bytes, entry: entry, digest: digest,
                                 to: directory, receiptURL: Self.receiptURL(), installed: &installed)
                changed += 1
                installedCount = installed.count
                releaseNotes = Self.readReleaseNotes()
            }
            // Las parejas se descargan y se validan COMPLETAS antes de publicar su índice.
            // El algoritmo rechaza originales actualizados sin variante compatible.
            for pair in manifest.compatiblePairs ?? [] {
                if !NXVersionedPairStore.needsUpdate(pair) { continue }
                status = "Verificando original y variante de \(pair.id)…"
                let originalURL = try Self.pairResourceURL(pair.original, source: source)
                let modifiedURL = try Self.pairResourceURL(pair.modified, source: source)
                let originalBytes = try await fetch(originalURL, limit: Self.maximumResourceSize)
                let modifiedBytes = try await fetch(modifiedURL, limit: Self.maximumResourceSize)
                try NXVersionedPairStore.install(pair,
                    original: originalBytes, modified: modifiedBytes)
                changed += 1
            }
            compatiblePairsCount = NXVersionedPairStore.installedCount()
            compatibilityStatus = NXVersionedPairStore.validationSummary()
            defaults.set(Date(), forKey: Self.lastCheckKey)
            status = changed == 0
                ? "Sin actualizaciones nuevas. \(compatibilityStatus)"
                : "\(changed) recurso(s) de NEXORA actualizado(s). \(compatibilityStatus)"
        } catch {
            status = "Actualización detenida: \(error.localizedDescription)"
            provenanceStatus = "Origen no verificado; operación detenida."
        }
    }

    func inspectCompatibility() {
        compatiblePairsCount = NXVersionedPairStore.installedCount()
        compatibilityStatus = NXVersionedPairStore.validationSummary()
    }

    func runOwnedPairDemo(activate: Bool) {
        do {
            if activate {
                try NXVersionedPairStore.activateOwnedPair(id: "nexora-demo")
                demoStatus = "Variante de prueba activada en datos PROPIOS de NEXORA."
            } else {
                try NXVersionedPairStore.restoreOwnedPair(id: "nexora-demo")
                demoStatus = "Original de prueba restaurado en datos PROPIOS de NEXORA."
            }
        } catch { demoStatus = "Operación detenida: \(error.localizedDescription)" }
        inspectCompatibility()
    }

    // Devuelve una ruta únicamente dentro de Application Support de NEXORA.
    static func installedResourceURL(for identifier: String) -> URL? {
        guard validID(identifier),
              let installed = try? loadInstalled(at: receiptURL()),
              let record = installed[identifier], validFile(record.file),
              let base = try? resourceDirectory() else { return nil }
        return base.appendingPathComponent(record.file, isDirectory: false)
    }

    // Un catálogo antiguo sin firma solo se utiliza para recursos propios de la app.
    // Si el propietario configura una clave, NO existe opción de degradar a sin firma.
    private static func verifiedManifest(_ data: Data, publicKeyBase64: String)
        throws -> (NXUpdateManifest, Bool) {
        let keyText = publicKeyBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        if let envelope = try? JSONDecoder().decode(NXSignedUpdateEnvelope.self, from: data) {
            guard envelope.format == "nexora-ed25519-v1",
                  let rawPublicKey = Data(base64Encoded: keyText), rawPublicKey.count == 32,
                  let signature = Data(base64Encoded: envelope.signatureBase64), signature.count == 64,
                  let payload = Data(base64Encoded: envelope.payloadBase64),
                  payload.count <= maximumManifestSize,
                  let key = try? Curve25519.Signing.PublicKey(rawRepresentation: rawPublicKey),
                  key.isValidSignature(signature, for: payload) else {
                throw NXUpdateFailure.invalidSignature
            }
            return (try JSONDecoder().decode(NXUpdateManifest.self, from: payload), true)
        }
        guard keyText.isEmpty else { throw NXUpdateFailure.unsignedManifest }
        return (try JSONDecoder().decode(NXUpdateManifest.self, from: data), false)
    }

    private func fetch(_ url: URL, limit: Int) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw NXUpdateFailure.invalidResponse
        }
        guard data.count <= limit else { throw NXUpdateFailure.tooLarge }
        return data
    }

    private static func validatedHTTPSURL(_ value: String) throws -> URL {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", url.host != nil,
              url.user == nil, url.password == nil, url.fragment == nil,
              url.port == nil else { throw NXUpdateFailure.invalidSource }
        return url
    }

    private static func validID(_ id: String) -> Bool {
        guard !id.isEmpty, id.utf8.count <= 64 else { return false }
        return id.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) ||
            (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }

    private static func validFile(_ file: String) -> Bool {
        guard !file.isEmpty, file.utf8.count <= 96,
              file.lowercased() != "installed.json",
              !file.hasPrefix("."), !file.contains(".."),
              !file.contains("/"), !file.contains("\\"),
              file.unicodeScalars.allSatisfy({ $0.isASCII && $0.value >= 32 }) else { return false }
        // Nunca aceptar aplicaciones, binarios ejecutables o perfiles.
        let allowed: Set<String> = ["json", "txt", "png", "jpg", "jpeg", "webp", "dat"]
        return allowed.contains((file as NSString).pathExtension.lowercased())
    }

    private static func validate(_ manifest: NXUpdateManifest, from source: URL) throws {
        var ids = Set<String>(), filenames = Set<String>()
        var total = 0
        for pair in manifest.compatiblePairs ?? [] {
            try NXVersionedPairStore.validate(pair)
            guard ids.insert(pair.id).inserted else { throw NXUpdateFailure.invalidResource }
            _ = try pairResourceURL(pair.original, source: source)
            _ = try pairResourceURL(pair.modified, source: source)
            total += pair.original.bytes + pair.modified.bytes
            guard total <= maximumTotalSize else { throw NXUpdateFailure.tooLarge }
        }
        for item in manifest.resources {
            guard validID(item.id), validFile(item.file), item.revision > 0,
                  item.bytes > 0, item.bytes <= maximumResourceSize,
                  item.sha256.count == 64,
                  item.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                  ids.insert(item.id).inserted,
                  filenames.insert(item.file).inserted else { throw NXUpdateFailure.invalidResource }
            total += item.bytes
            guard total <= maximumTotalSize else { throw NXUpdateFailure.tooLarge }
            _ = try resourceURL(item, source: source)
        }
    }

    private static func pairResourceURL(_ item: NXPairRemoteFile, source: URL) throws -> URL {
        try checkedSameHostURL(item.url, source: source)
    }

    private static func resourceURL(_ item: NXRemoteResource, source: URL) throws -> URL {
        try checkedSameHostURL(item.url, source: source)
    }

    private static func checkedSameHostURL(_ path: String, source: URL) throws -> URL {
        guard let candidate = URL(string: path, relativeTo: source)?.absoluteURL,
              candidate.scheme?.lowercased() == "https",
              candidate.host?.lowercased() == source.host?.lowercased(),
              candidate.port == source.port,
              candidate.user == nil, candidate.password == nil,
              candidate.fragment == nil else { throw NXUpdateFailure.invalidResource }
        return candidate
    }

    private static func resourceDirectory() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil, create: true)
            .appendingPathComponent("NexoraOwnedResources", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func receiptURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
        return root.appendingPathComponent("NexoraOwnedResources/installed.json")
    }

    private static func loadInstalled(at url: URL) throws -> [String: NXInstalledResource] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode([String: NXInstalledResource].self,
                                        from: Data(contentsOf: url))
    }

    private static func installedBytesMatch(_ entry: NXInstalledResource, at root: URL) -> Bool {
        guard validFile(entry.file), let bytes = try? Data(contentsOf: root.appendingPathComponent(entry.file)),
              bytes.count <= maximumResourceSize else { return false }
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        return digest == entry.sha256
    }

    private static func readReleaseNotes() -> String {
        guard let file = installedResourceURL(for: "release-notes"),
              let text = try? String(contentsOf: file, encoding: .utf8) else { return "" }
        return String(text.prefix(1200))
    }

    // Si el proceso se interrumpió entre respaldar y confirmar el recibo,
    // recupera el archivo anterior. No toca carpetas fuera de Application Support.
    private static func recoverInterruptedTransactions(at root: URL) {
        // Incluye carpetas ocultas: las transacciones comienzan por punto.
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: []) else { return }
        let receipts = (try? loadInstalled(at: receiptURL())) ?? [:]
        for work in entries where work.lastPathComponent.hasPrefix(".transaction-") {
            let journalURL = work.appendingPathComponent("journal.json")
            guard let bytes = try? Data(contentsOf: journalURL),
                  let journal = try? JSONDecoder().decode(NXUpdateJournal.self, from: bytes),
                  validID(journal.id), validFile(journal.filename) else { continue }
            let destination = root.appendingPathComponent(journal.filename)
            let backup = work.appendingPathComponent("old")
            let committed = receipts[journal.id].map {
                $0.revision >= journal.revision && installedBytesMatch($0, at: root)
            } ?? false
            var recovered = true
            if !committed {
                if journal.hadPrevious {
                    if FileManager.default.fileExists(atPath: backup.path) {
                        // Solo eliminar el destino cuando existe un respaldo real.
                        // Antes de guardar ese respaldo, el original sigue en destino.
                        do {
                            if FileManager.default.fileExists(atPath: destination.path) {
                                try FileManager.default.removeItem(at: destination)
                            }
                            try FileManager.default.moveItem(at: backup, to: destination)
                        } catch { recovered = false }
                    } else if !FileManager.default.fileExists(atPath: destination.path) {
                        recovered = false // No borrar el diario sin recuperar el original.
                    }
                } else if FileManager.default.fileExists(atPath: destination.path) {
                    do { try FileManager.default.removeItem(at: destination) }
                    catch { recovered = false }
                }
            }
            if recovered { try? FileManager.default.removeItem(at: work) }
        }
    }

    private static func install(_ data: Data, entry: NXRemoteResource, digest: String,
                                to root: URL, receiptURL: URL,
                                installed: inout [String: NXInstalledResource]) throws {
        let manager = FileManager.default
        let destination = root.appendingPathComponent(entry.file, isDirectory: false)
        let work = root.appendingPathComponent(".transaction-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: work, withIntermediateDirectories: false)
        var mayRemoveWorkspace = true
        defer { if mayRemoveWorkspace { try? manager.removeItem(at: work) } }
        let hadOld = manager.fileExists(atPath: destination.path)
        let journal = NXUpdateJournal(id: entry.id, filename: entry.file,
                                     revision: entry.revision, hadPrevious: hadOld)
        try JSONEncoder().encode(journal).write(
            to: work.appendingPathComponent("journal.json"), options: .atomic)
        let staged = work.appendingPathComponent("new", isDirectory: false)
        let backup = work.appendingPathComponent("old", isDirectory: false)
        try data.write(to: staged, options: .atomic)
        if hadOld {
            try manager.moveItem(at: destination, to: backup)
        }
        do {
            try manager.moveItem(at: staged, to: destination)
            var next = installed
            next[entry.id] = NXInstalledResource(revision: entry.revision,
                                                sha256: digest, file: entry.file)
            try JSONEncoder().encode(next).write(to: receiptURL, options: .atomic)
            installed = next
        } catch {
            try? manager.removeItem(at: destination)
            if hadOld {
                do { try manager.moveItem(at: backup, to: destination) }
                catch { mayRemoveWorkspace = false } // Recuperar al abrir NEXORA.
            }
            throw error
        }
    }
}
