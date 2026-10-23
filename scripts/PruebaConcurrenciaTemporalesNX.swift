import Foundation

@main
struct NXTemporaryConcurrencyTest {
    static func main() throws {
        let manager = FileManager.default
        let identifier = UUID()
        let count = 48
        defer { _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: identifier) }

        let resultLock = NSLock()
        var failures: [String] = []
        DispatchQueue.concurrentPerform(iterations: count) { index in
            do {
                let filename = "simultaneous-\(index).tmp"
                let data = Data("contenido-\(index)".utf8)
                let url = try NXOwnedTemporaryWorkspaces.create(
                    data: data, optionID: identifier, filename: filename
                )
                guard try Data(contentsOf: url) == data else {
                    throw NSError(domain: "NEXORA", code: 1)
                }
            } catch {
                resultLock.lock()
                failures.append("\(index): \(error)")
                resultLock.unlock()
            }
        }
        guard failures.isEmpty else {
            fatalError("Error de concurrencia: \(failures)")
        }
        let removed = try NXOwnedTemporaryWorkspaces.clean(optionID: identifier)
        guard removed == count, try NXOwnedTemporaryWorkspaces.isClean(optionID: identifier) else {
            fatalError("Faltan temporales o quedó una carpeta residual")
        }
        print("OK: \(count) creaciones concurrentes y limpieza consistente")

        // Comprueba que una limpieza manual general no elimine un espacio marcado
        // como protegido aunque contenga temporales normales.
        let protected = UUID()
        let payload = Data("conservar original".utf8)
        let file = try NXOwnedTemporaryWorkspaces.create(
            data: payload, optionID: protected, filename: "resguardar.tmp"
        )
        defer { _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: protected) }
        let report = try NXOwnedTemporaryWorkspaces.cleanAll(keeping: [protected])
        guard report.protectedWorkspaces >= 1,
              manager.fileExists(atPath: file.path),
              try Data(contentsOf: file) == payload else {
            fatalError("La limpieza borró un espacio protegido")
        }
        print("OK: espacios protegidos preservados")
    }
}
