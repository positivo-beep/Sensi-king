import Foundation
@main struct PruebaAntenaMulti {
    static func main() throws {
        var success = 0
        for path in CommandLine.arguments.dropFirst() {
            let url = URL(fileURLWithPath:path)
            let raw = try Data(contentsOf:url)
            let isBad = url.lastPathComponent.contains("bad_profile")
            do {
                let modified = try NXAntennaOnlyUnityFS.build(from:raw, rejectKnownModified:false)
                if isBad { fatalError("Se modificó un perfil incompatible") }
                let old = try NXAntennaOnlyUnityFS.unpackForTesting(raw)
                let new = try NXAntennaOnlyUnityFS.unpackForTesting(modified)
                guard old.count == new.count else { fatalError("Changed size") }
                var differences = 0
                for i in old.indices where old[i] != new[i] { differences += 1 }
                guard differences == 4 else { fatalError("Cambios inesperados: \(differences)") }
                guard raw.suffix(11) == modified.suffix(11) else { fatalError("Suffix perdido") }
                success += 1
                print("OK \(url.lastPathComponent)")
            } catch {
                if isBad { success += 1; print("OK rechazó perfil incompatible: \(error)") }
                else { throw error }
            }
        }
        print("ANTENA: \(success) pruebas de estructura/integridad correctas")
    }
}
