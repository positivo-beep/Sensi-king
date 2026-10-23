import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

func testSHA(_ url: URL) throws -> Data {
    #if canImport(CryptoKit)
    return Data(SHA256.hash(data: try Data(contentsOf: url)))
    #else
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    proc.arguments = ["shasum", "-a", "256", url.path]
    let pipe = Pipe()
    proc.standardOutput = pipe
    try proc.run()
    let out = pipe.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    guard proc.terminationStatus == 0,
          let text = String(data: out, encoding: .utf8),
          let hex = text.split(separator: " ").first, hex.count == 64 else {
        throw NSError(domain: "TEST", code: 2)
    }
    var bytes: [UInt8] = []
    for index in stride(from: 0, to: 64, by: 2) {
        let start = hex.index(hex.startIndex, offsetBy: index)
        let end = hex.index(start, offsetBy: 2)
        guard let byte = UInt8(hex[start..<end], radix: 16) else { throw NSError(domain: "TEST", code: 3) }
        bytes.append(byte)
    }
    return Data(bytes)
    #endif
}

@main struct NXRevisionTests {
    static func main() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("nx-revision-test-\(UUID().uuidString)")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let original = base.appendingPathComponent("current.bin")
        let ledgerRoot = base.appendingPathComponent("Backups")
        let ident = base.appendingPathComponent("identity.bin")
        try Data("application/file.dat".utf8).write(to: ident)
        let key = try testSHA(ident)
        let label = "my.owned.app/Documents/file.dat"
        func save(_ digest: Data, source: NXOriginalRevisionLedger.Source = .externalChange) throws -> Bool {
            try NXOriginalRevisionLedger.preserveIfNew(
                sourceURL: original, backupRoot: ledgerRoot,
                logicalKeySHA256: key, targetDescription: label,
                expectedDigest: digest, reason: source, digestFile: testSHA
            )
        }
        // Una observación histórica, y mismo contenido repetido.
        try Data("original-v1".utf8).write(to: original)
        let first = try testSHA(original)
        let firstAdded = try save(first, source: .initialObservation)
        assert(firstAdded)
        let firstRepeat = try save(first)
        assert(!firstRepeat)
        // Un byte diferente: nueva revisión inmutable. NO sobrescribir la previa.
        try Data("original-v2".utf8).write(to: original)
        let second = try testSHA(original)
        assert(first != second)
        let secondAdded = try save(second)
        assert(secondAdded)
        let secondRepeat = try save(second)
        assert(!secondRepeat)
        let keyDir = ledgerRoot.appendingPathComponent("_OriginalRevisions")
            .appendingPathComponent(key.map { String(format: "%02x", $0) }.joined())
        var revisions = try fm.contentsOfDirectory(at: keyDir, includingPropertiesForKeys: nil)
        assert(revisions.filter { !$0.lastPathComponent.hasPrefix(".") }.count == 2)
        let firstDir = keyDir.appendingPathComponent(first.map { String(format: "%02x", $0) }.joined())
        let secondDir = keyDir.appendingPathComponent(second.map { String(format: "%02x", $0) }.joined())
        let firstCheck = try testSHA(firstDir.appendingPathComponent("observed-original.bin"))
        assert(firstCheck == first)
        let secondCheck = try testSHA(secondDir.appendingPathComponent("observed-original.bin"))
        assert(secondCheck == second)
        let entry = try JSONDecoder().decode(NXOriginalRevisionLedger.Revision.self,
            from: Data(contentsOf: secondDir.appendingPathComponent("revision.json")))
        assert(entry.provenanceVerified == false)
        // Si el archivo cambió durante la copia/entre cálculos, RECHAZAR.
        var staleDetected = false
        do { _ = try save(first) } catch { staleDetected = true }
        assert(staleDetected)
        // No debe confiarse en una revisión previamente almacenada si está corrupta.
        try Data("damaged".utf8).write(to: secondDir.appendingPathComponent("observed-original.bin"))
        var corruptionDetected = false
        do { _ = try save(second) } catch { corruptionDetected = true }
        assert(corruptionDetected)
        // No seguir enlaces simbólicos externos, ni agregar revisión.
        let link = base.appendingPathComponent("linked")
        try fm.createSymbolicLink(at: link, withDestinationURL: original)
        var linkRejected = false
        do {
            _ = try NXOriginalRevisionLedger.preserveIfNew(
                sourceURL: link, backupRoot: ledgerRoot, logicalKeySHA256: key,
                targetDescription: label, expectedDigest: second,
                reason: .externalChange, digestFile: testSHA
            )
        } catch { linkRejected = true }
        assert(linkRejected)
        revisions = try fm.contentsOfDirectory(at: keyDir, includingPropertiesForKeys: nil)
        assert(revisions.filter { !$0.lastPathComponent.hasPrefix(".") }.count == 2)
        print("OK: respaldo automático, idempotencia, 1 byte, copia antigua, integridad, symlink y procedencia no verificada.")
    }
}
