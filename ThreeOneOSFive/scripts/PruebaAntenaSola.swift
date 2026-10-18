import Foundation

@main
struct PruebaAntenaSola {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 7 else { fatalError("Uso: PruebaAntenaSola AIM1 ANT1 AIM2 ANT2 AIM3 ANT3") }
        var good = 0
        for n in 0..<3 {
            let normal = try Data(contentsOf: URL(fileURLWithPath: args[1 + n * 2]))
            let withAntenna = try Data(contentsOf: URL(fileURLWithPath: args[2 + n * 2]))
            #if canImport(CryptoKit)
            // Un AIMBOT conocido nunca debe utilizarse como base limpia en producción.
            do {
                _ = try NXAntennaOnlyUnityFS.build(from: normal)
                fatalError("Un archivo AIMBOT conocido fue aceptado como original limpio")
            } catch NXAntennaOnlyUnityFS.Failure.unsupported { }
            #endif
            let converted = try NXAntennaOnlyUnityFS.build(from: normal, rejectKnownModified: false)
            let decodedConverted = try NXAntennaOnlyUnityFS.unpackForTesting(converted)
            let decodedExpected = try NXAntennaOnlyUnityFS.unpackForTesting(withAntenna)
            guard decodedConverted == decodedExpected else { fatalError("Par \(n + 1): conversión no coincide con archivo AIM+ANTENA") }
            let inNormal = try NXAntennaOnlyUnityFS.unpackForTesting(normal)
            let changes = zip(inNormal, decodedConverted).enumerated().filter { $0.element.0 != $0.element.1 }.map(\.offset)
            guard changes == [25262,25263,38922,38923] else { fatalError("Cambios inesperados en el par \(n + 1): \(changes)") }
            guard converted != normal else { fatalError("El archivo no se modificó") }
            do {
                _ = try NXAntennaOnlyUnityFS.build(from: withAntenna, rejectKnownModified: false)
                fatalError("Se aceptó un original ya modificado con ANTENA")
            } catch NXAntennaOnlyUnityFS.Failure.unsupported { }
            good += 1
            print("OK par \(n + 1): UnityFS válido, dos valores modificados y datos equivalentes a AIM+ANTENA")
        }
        do {
            _ = try NXAntennaOnlyUnityFS.build(from: Data([0, 1, 2, 3]), rejectKnownModified: false)
            fatalError("Se aceptó un recurso sin UnityFS")
        } catch NXAntennaOnlyUnityFS.Failure.unsupported { }
        print("OK: los datos truncados o no compatibles se rechazan")
        print("ANTENA: \(good)/3 comparaciones pasaron. No demuestra ausencia de AIMBOT en archivos desconocidos.")
    }
}
