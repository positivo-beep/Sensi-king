import Foundation

// Pruebas funcionales reales de PatchTransaction sobre un directorio temporal.
// Nunca acceden a carpetas de juegos ni de otras aplicaciones.
@main
struct PruebaMotorTransacciones {
    static let bundle = "com.nexora.test.local"
    static let manager = FileManager.default

    struct Fixture {
        let root: URL
        let sandbox: URL
        let backups: URL
        let target: URL
        let project: PatchProject

        init(original: String? = "ORIGINAL", replacement: String = "MODIFICADO", path: String = "data/file.bin") throws {
            root = manager.temporaryDirectory.appendingPathComponent("NX-Motor-\(UUID().uuidString)", isDirectory: true)
            // El nombre UUID se genera sin depender de carpetas externas.
            sandbox = root.appendingPathComponent("Sandbox", isDirectory: true)
            backups = root.appendingPathComponent("Backups", isDirectory: true)
            target = sandbox.appendingPathComponent(path)
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try manager.createDirectory(at: backups, withIntermediateDirectories: true)
            if let original { try Data(original.utf8).write(to: target) }
            project = PatchProject(name: "prueba", rules: [PatchRule(
                bundleID: bundle, relativePath: path,
                replacementFilename: "nuevo.bin", replacementData: Data(replacement.utf8))])
        }
        func resolve(_ id: String) throws -> URL {
            guard id == bundle else { throw PatchPackageError.targetAppUnavailable(id) }
            return sandbox
        }
        func read() throws -> String? {
            guard manager.fileExists(atPath: target.path) else { return nil }
            return String(data: try Data(contentsOf: target), encoding: .utf8)
        }
        func write(_ value: String) throws {
            try Data(value.utf8).write(to: target, options: .atomic)
        }
        func dispose() { try? manager.removeItem(at: root) }
    }

    static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() {
            throw NSError(domain: "NEXORA.Test", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    static func execute(_ title: String, _ body: () throws -> Void) -> Bool {
        do {
            try body()
            print("OK | \(title)")
            return true
        } catch {
            print("ERROR | \(title): \(error)")
            return false
        }
    }

    static func main() {
        let results: [Bool] = [
            execute("Respaldo y restauración byte a byte") {
                let f = try Fixture(original: "ORIGINAL-123", replacement: "REEMPLAZO-345")
                defer { f.dispose() }
                let r = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                try require(f.read() == "REEMPLAZO-345", "No se aplicó el reemplazo")
                try require(!r.journalURL.path.isEmpty, "Falta registro")
                try require(PatchTransaction.latestReceipt(projectID: f.project.id, backupRoot: f.backups) != nil, "No existe recibo")
                _ = try PatchTransaction.restore(receipt: r, containerResolver: f.resolve)
                try require(f.read() == "ORIGINAL-123", "No restauró el original")
                try require(PatchTransaction.latestReceipt(projectID: f.project.id, backupRoot: f.backups) == nil, "Recibo activo después de restaurar")
            },
            execute("Detectar modificación externa y conservar contenido") {
                let f = try Fixture(); defer { f.dispose() }
                let r = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                try f.write("ACTUALIZADO")
                let state = try PatchTransaction.inspectRestore(receipt: r, containerResolver: f.resolve)
                try require(state.changedTargets.count == 1 && state.changedTargets[0].kind == .modified, "No detectó cambio externo")
                do {
                    _ = try PatchTransaction.restore(receipt: r, containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Restauró sin avisar"])
                } catch PatchPackageError.restoreTargetsChanged { /* correcto */ }
                try require(f.read() == "ACTUALIZADO", "Sobrescribió archivo cambiado")
                let preserved = try PatchTransaction.restore(receipt: r, preserveExternallyChangedTargets: true, containerResolver: f.resolve)
                try require(preserved.count == 1 && f.read() == "ACTUALIZADO", "No preservó actualización")
            },
            execute("Aviso de nueva versión y respaldo vigente") {
                let f = try Fixture(); defer { f.dispose() }
                let r = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                try f.write("NUEVO-ORIGINAL")
                _ = try PatchTransaction.restore(receipt: r, preserveExternallyChangedTargets: true, containerResolver: f.resolve)
                do {
                    _ = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "No avisó de la versión actualizada"])
                } catch PatchPackageError.originalVersionChanged { /* correcto */ }
                try require(f.read() == "NUEVO-ORIGINAL", "Alteró el archivo antes de confirmar")
                let r2 = try PatchTransaction.apply(project: f.project, backupRoot: f.backups,
                                                    allowUpdatedOriginal: true, containerResolver: f.resolve)
                _ = try PatchTransaction.restore(receipt: r2, containerResolver: f.resolve)
                try require(f.read() == "NUEVO-ORIGINAL", "Restauró versión antigua")
            },
            execute("No restaurar un archivo desaparecido") {
                let f = try Fixture(); defer { f.dispose() }
                let r = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                try manager.removeItem(at: f.target)
                do {
                    _ = try PatchTransaction.restore(receipt: r, preserveExternallyChangedTargets: true, containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Restauró un archivo desaparecido sin confirmación"])
                } catch PatchPackageError.restoreTargetsChanged { /* correcto */ }
                try require(f.read() == nil, "Creó archivo sin permiso")
            },
            execute("Cambios del mismo tamaño detectados por huella") {
                let f = try Fixture(original: "AAAA", replacement: "BBBB"); defer { f.dispose() }
                let r = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                try f.write("CCCC")
                let state = try PatchTransaction.inspectRestore(receipt: r, containerResolver: f.resolve)
                try require(state.changedTargets.count == 1 && state.changedTargets[0].kind == .modified, "SHA no detectó cambio de tamaño igual")
            },
            execute("Bloqueo de doble activación") {
                let f = try Fixture(); defer { f.dispose() }
                _ = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                do {
                    _ = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Permitió doble aplicación"])
                } catch PatchPackageError.projectAlreadyApplied { /* correcto */ }
            },
            execute("Exclusión mutua de opciones con el mismo destino") {
                let f = try Fixture(); defer { f.dispose() }
                _ = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                let other = PatchProject(name: "otra variante", rules: [PatchRule(
                    bundleID: bundle, relativePath: "data/file.bin",
                    replacementFilename: "otro.bin", replacementData: Data("OTRA".utf8))])
                do {
                    _ = try PatchTransaction.apply(project: other, backupRoot: f.backups, containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Permitió opciones simultáneas"])
                } catch PatchPackageError.targetOccupied { /* correcto */ }
                try require(f.read() == "MODIFICADO", "Dañó la primera opción")
            },
            execute("Recuperación si falla la segunda escritura") {
                let f = try Fixture(); defer { f.dispose() }
                let second = f.sandbox.appendingPathComponent("data/second.bin")
                try Data("SEGUNDO-ORIGINAL".utf8).write(to: second)
                var project = f.project
                project.rules.append(PatchRule(bundleID: bundle, relativePath: "data/second.bin",
                                               replacementFilename: "segundo.bin", replacementData: Data("SEGUNDO-MOD".utf8)))
                do {
                    _ = try PatchTransaction.apply(project: project, backupRoot: f.backups,
                        containerResolver: f.resolve, beforeWrite: { if $0 == 1 { throw PatchPackageError.applyFailed } })
                    throw NSError(domain: "NEXORA.Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "No falló como se esperaba"])
                } catch PatchPackageError.applyFailed { /* correcto */ }
                try require(f.read() == "ORIGINAL", "No recuperó el primer archivo")
                try require(String(data: try Data(contentsOf: second), encoding: .utf8) == "SEGUNDO-ORIGINAL", "No recuperó el segundo")
            },
            execute("Recuperación si falla la restauración intermedia") {
                let f = try Fixture(); defer { f.dispose() }
                let second = f.sandbox.appendingPathComponent("data/second.bin")
                try Data("SEGUNDO-ORIGINAL".utf8).write(to: second)
                var project = f.project
                project.rules.append(PatchRule(bundleID: bundle, relativePath: "data/second.bin",
                                               replacementFilename: "segundo.bin", replacementData: Data("SEGUNDO-MOD".utf8)))
                let r = try PatchTransaction.apply(project: project, backupRoot: f.backups, containerResolver: f.resolve)
                do {
                    _ = try PatchTransaction.restore(receipt: r, containerResolver: f.resolve,
                        beforeWrite: { if $0 == 1 { throw PatchPackageError.restoreFailed } })
                    throw NSError(domain: "NEXORA.Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "No falló como se esperaba"])
                } catch PatchPackageError.restoreFailed { /* correcto */ }
                try require(f.read() == "MODIFICADO", "No restauró estado aplicado tras fallo")
                try require(String(data: try Data(contentsOf: second), encoding: .utf8) == "SEGUNDO-MOD", "No revirtió cambio parcial")
                _ = try PatchTransaction.restore(receipt: r, containerResolver: f.resolve)
                try require(f.read() == "ORIGINAL", "Falló reintento de restauración")
            },
            execute("Nunca restaurar con respaldo alterado") {
                let f = try Fixture(); defer { f.dispose() }
                let r = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                let files = try manager.contentsOfDirectory(at: r.journalURL.deletingLastPathComponent(), includingPropertiesForKeys: nil)
                guard let backup = files.first(where: { $0.lastPathComponent.hasSuffix(".original") }) else {
                    throw NSError(domain: "NEXORA.Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Falta respaldo"])
                }
                try Data("RESPALDO-ALTERADO".utf8).write(to: backup)
                do {
                    _ = try PatchTransaction.restore(receipt: r, containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Restauró respaldo corrupto"])
                } catch PatchPackageError.restoreFailed { /* correcto */ }
                try require(f.read() == "MODIFICADO", "Modificó archivo antes de comprobar respaldo")
            },
            execute("Eliminar archivo creado sin original previo") {
                let f = try Fixture(original: nil); defer { f.dispose() }
                let r = try PatchTransaction.apply(project: f.project, backupRoot: f.backups, containerResolver: f.resolve)
                try require(f.read() == "MODIFICADO", "No creó el archivo")
                _ = try PatchTransaction.restore(receipt: r, containerResolver: f.resolve)
                try require(f.read() == nil, "No eliminó archivo creado")
            }
        ]
        let count = results.filter { $0 }.count
        print("RESULTADO FUNCIONAL: \(count)/\(results.count) casos correctos")
        if count != results.count { exit(1) }
    }
}
