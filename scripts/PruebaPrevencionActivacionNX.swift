import Foundation

@main
struct PruebaPrevencionActivacionNX {
    static func main() throws {
        let fm = FileManager.default
        let resources = CommandLine.arguments.dropFirst().map(URL.init(fileURLWithPath:))
        guard resources.count == 15 else { fatalError("Se esperaban los 15 recursos del catálogo") }
        for url in resources {
            try NXActivationPreflight.validateBundledResource(Data(contentsOf: url))
        }
        var damaged = try Data(contentsOf: resources[0])
        damaged[0] ^= 1
        do {
            try NXActivationPreflight.validateBundledResource(damaged)
            fatalError("Fallo: aceptó la cabecera dañada")
        } catch NXActivationPreflight.Failure.invalidResource { }
        let work = fm.temporaryDirectory.appendingPathComponent("nexora-preflight-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let original = work.appendingPathComponent("original.unityfs")
        try fm.copyItem(at: resources[0], to: original)
        try NXActivationPreflight.validateReadableWritableOriginal(at: original)
        let missing = work.appendingPathComponent("no-existe")
        do {
            try NXActivationPreflight.validateReadableWritableOriginal(at: missing)
            fatalError("Fallo: aceptó original ausente")
        } catch NXActivationPreflight.Failure.missingOriginal { }
        let invalid = work.appendingPathComponent("texto.txt")
        try Data("no es UnityFS".utf8).write(to: invalid)
        do {
            try NXActivationPreflight.validateReadableWritableOriginal(at: invalid)
            fatalError("Fallo: aceptó el archivo inválido")
        } catch NXActivationPreflight.Failure.invalidOriginal { }
        let alias = work.appendingPathComponent("enlace")
        try fm.createSymbolicLink(at: alias, withDestinationURL: original)
        do {
            try NXActivationPreflight.validateReadableWritableOriginal(at: alias)
            fatalError("Fallo: aceptó enlace simbólico")
        } catch NXActivationPreflight.Failure.invalidOriginal { }
        print("OK: 15 recursos verificados; firma dañada, original ausente, inválido y enlace rechazados; original legítimamente accesible aceptado.")
    }
}
