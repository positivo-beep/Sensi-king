import Foundation
import CryptoKit

// Pruebas funcionales reales de PatchTransaction sobre un directorio temporal.
// Nunca acceden a carpetas de juegos ni de otras aplicaciones.
@main
struct PruebaMotorTransacciones {
    static let bundle = "com.nexora.test.local"
    static let manager = FileManager.default

    final class ConcurrentReceiptBox: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [(UUID, PatchTransactionReceipt)] = []
        func append(_ item: (UUID, PatchTransactionReceipt)) {
            lock.lock(); defer { lock.unlock() }
            values.append(item)
        }
        func snapshot() -> [(UUID, PatchTransactionReceipt)] {
            lock.lock(); defer { lock.unlock() }
            return values
        }
    }

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
                } catch PatchPackageError.updatedReplacementRequired { /* correcto */ }
                try require(f.read() == "NUEVO-ORIGINAL", "Alteró el archivo antes de confirmar")
                do {
                    _ = try PatchTransaction.apply(project: f.project, backupRoot: f.backups,
                                                   allowUpdatedOriginal: true, containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Aceptó paquete antiguo"])
                } catch PatchPackageError.updatedReplacementRequired { /* correcto */ }
                // El propietario aporta un nuevo archivo modificado para el original
                // actualizado, junto con su SHA-256. La restauracion debe recuperar v2.
                var updatedPackage = f.project
                let newOriginal = Data("NUEVO-ORIGINAL".utf8)
                let currentRule = updatedPackage.rules[0]
                updatedPackage.rules[0] = PatchRule(
                    id: currentRule.id, bundleID: currentRule.bundleID,
                    relativePath: currentRule.relativePath,
                    replacementFilename: "modificado-v2.bin",
                    replacementData: Data("MODIFICADO-v2".utf8),
                    expectedOriginalSHA256: SHA256.hash(data: newOriginal)
                        .map { String(format: "%02x", $0) }.joined()
                )
                let r2 = try PatchTransaction.apply(project: updatedPackage,
                    backupRoot: f.backups, containerResolver: f.resolve)
                try require(f.read() == "MODIFICADO-v2", "No uso archivo actualizado")
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
            execute("Bloqueo de hash original incompatible en primera aplicacion") {
                let f = try Fixture(original: "ORIGINAL-A", replacement: "MOD-A")
                defer { f.dispose() }
                var p = f.project
                let rule = p.rules[0]
                p.rules[0] = PatchRule(
                    id: rule.id, bundleID: rule.bundleID, relativePath: rule.relativePath,
                    replacementFilename: rule.replacementFilename,
                    replacementData: rule.replacementData,
                    expectedOriginalSHA256: String(repeating: "0", count: 64))
                do {
                    _ = try PatchTransaction.apply(project: p, backupRoot: f.backups,
                                                    containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Aplicó paquete con SHA errado"])
                } catch PatchPackageError.incompatibleOriginalVersion { /* correcto */ }
                try require(f.read() == "ORIGINAL-A", "Alteró original incompatible")
                try require(PatchTransaction.latestReceipt(projectID: p.id,
                       backupRoot: f.backups) == nil, "Dejó una activación fantasma")
            },
            execute("Bloquear payload antiguo aunque se actualice su SHA vinculado") {
                let f = try Fixture(original: "ORIGINAL-A", replacement: "MOD-A")
                defer { f.dispose() }
                let r = try PatchTransaction.apply(project: f.project, backupRoot: f.backups,
                                                   containerResolver: f.resolve)
                try f.write("ORIGINAL-B")
                _ = try PatchTransaction.restore(receipt: r,
                    preserveExternallyChangedTargets: true, containerResolver: f.resolve)
                var p = f.project
                let old = p.rules[0]
                p.rules[0] = PatchRule(
                    id: old.id, bundleID: old.bundleID, relativePath: old.relativePath,
                    replacementFilename: old.replacementFilename,
                    replacementData: old.replacementData,
                    expectedOriginalSHA256: SHA256.hash(data: Data("ORIGINAL-B".utf8))
                        .map { String(format: "%02x", $0) }.joined())
                do {
                    _ = try PatchTransaction.apply(project: p, backupRoot: f.backups,
                                                   allowUpdatedOriginal: true,
                                                   containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Aplicó reemplazo anterior"])
                } catch PatchPackageError.updatedReplacementRequired { /* correcto */ }
                try require(f.read() == "ORIGINAL-B", "Dañó original al usar paquete viejo")
            },
            execute("No sobrescribir original actualizado justo al activar") {
                let f = try Fixture(original: "V1", replacement: "CAMBIO-NEXORA")
                defer { f.dispose() }
                do {
                    _ = try PatchTransaction.apply(project: f.project, backupRoot: f.backups,
                        containerResolver: f.resolve, beforeWrite: { index in
                            if index == 0 { try f.write("V2-EXTERNO") }
                        })
                    throw NSError(domain: "NEXORA.Test", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Pisó original cambiado antes de aplicar"])
                } catch PatchPackageError.incompatibleOriginalVersion { /* correcto */ }
                try require(f.read() == "V2-EXTERNO", "No conservó el original actualizado")
                try require(PatchTransaction.latestReceipt(projectID: f.project.id,
                    backupRoot: f.backups) == nil, "Quedó activación pendiente sin escrituras")
            },
            execute("Revertir primer archivo sin borrar cambio externo en segundo") {
                let f = try Fixture(); defer { f.dispose() }
                let second = f.sandbox.appendingPathComponent("data/second.bin")
                try Data("ORIGINAL-SEGUNDO".utf8).write(to: second)
                var project = f.project
                project.rules.append(PatchRule(bundleID: bundle,
                    relativePath: "data/second.bin", replacementFilename: "new.bin",
                    replacementData: Data("REEMPLAZO-SEGUNDO".utf8)))
                do {
                    _ = try PatchTransaction.apply(project: project, backupRoot: f.backups,
                        containerResolver: f.resolve, beforeWrite: { index in
                            if index == 1 { try Data("SEGUNDO-V2-EXTERNO".utf8).write(to: second) }
                        })
                    throw NSError(domain: "NEXORA.Test", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "No abortó cambio externo"])
                } catch PatchPackageError.incompatibleOriginalVersion { /* correcto */ }
                try require(f.read() == "ORIGINAL", "No restauró el primer archivo escrito")
                let secondContent = String(data: try Data(contentsOf: second), encoding: .utf8)
                try require(secondContent == "SEGUNDO-V2-EXTERNO", "Pisó un destino que nunca escribió")
                try require(PatchTransaction.latestReceipt(projectID: project.id,
                    backupRoot: f.backups) == nil, "No cerró la transacción recuperada")
            },
            execute("Archivo nuevo que apareció antes de activar queda intacto") {
                let f = try Fixture(original: nil); defer { f.dispose() }
                do {
                    _ = try PatchTransaction.apply(project: f.project, backupRoot: f.backups,
                        containerResolver: f.resolve, beforeWrite: { index in
                            if index == 0 { try f.write("CREADO-POR-OTRO") }
                        })
                    throw NSError(domain: "NEXORA.Test", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Reemplazó el archivo recién creado"])
                } catch PatchPackageError.incompatibleOriginalVersion { /* correcto */ }
                try require(f.read() == "CREADO-POR-OTRO", "Borró un archivo ajeno")
            },
            execute("No pisar cambio externo de archivo ya aplicado al fallar después") {
                let f = try Fixture(); defer { f.dispose() }
                let second = f.sandbox.appendingPathComponent("data/second.bin")
                try Data("SEGUNDO-ORIGINAL".utf8).write(to: second)
                var project = f.project
                project.rules.append(PatchRule(bundleID: bundle,
                    relativePath: "data/second.bin", replacementFilename: "new.bin",
                    replacementData: Data("SEGUNDO-NEXORA".utf8)))
                do {
                    _ = try PatchTransaction.apply(project: project, backupRoot: f.backups,
                        containerResolver: f.resolve, beforeWrite: { index in
                            if index == 1 {
                                try f.write("CAMBIO-EXTERNO-TRAS-PRIMERA-ESCRITURA")
                                throw PatchPackageError.applyFailed
                            }
                        })
                    throw NSError(domain: "NEXORA.Test", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "No reportó interrupción"])
                } catch PatchPackageError.applyFailed { /* correcto */ }
                try require(f.read() == "CAMBIO-EXTERNO-TRAS-PRIMERA-ESCRITURA",
                    "Sobrescribió modificación externa al revertir")
                try require(String(data: try Data(contentsOf: second), encoding: .utf8) == "SEGUNDO-ORIGINAL",
                    "Modificó destino pendiente")
                let unresolved = PatchTransaction.latestReceipt(projectID: project.id,
                    backupRoot: f.backups)
                try require(unresolved != nil,
                    "Perdió diario de recuperación cuando no podía revertir todo")
                if let unresolved {
                    do {
                        _ = try PatchTransaction.restore(receipt: unresolved,
                            containerResolver: f.resolve)
                        throw NSError(domain: "NEXORA.Test", code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "Restauró un cambio externo en transacción preparada"])
                    } catch PatchPackageError.restoreTargetsChanged { /* correcto */ }
                    try require(f.read() == "CAMBIO-EXTERNO-TRAS-PRIMERA-ESCRITURA",
                        "La recuperación pisó la actualización ajena")
                }
            },
            execute("Cambio externo en plena restauración impide pisar actualización") {
                let f = try Fixture(); defer { f.dispose() }
                let r = try PatchTransaction.apply(project: f.project,
                    backupRoot: f.backups, containerResolver: f.resolve)
                do {
                    _ = try PatchTransaction.restore(receipt: r,
                        containerResolver: f.resolve, beforeWrite: { index in
                            if index == 0 { try f.write("ORIGINAL-EXTERNO-NUEVO") }
                        })
                    throw NSError(domain: "NEXORA.Test", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Sobrescribió actualización durante restauración"])
                } catch PatchPackageError.restoreTargetsChanged { /* correcto */ }
                try require(f.read() == "ORIGINAL-EXTERNO-NUEVO",
                    "Recuperación pisó actualización externa")
                try require(PatchTransaction.latestReceipt(projectID: f.project.id,
                    backupRoot: f.backups) != nil, "Se cerró incorrectamente una restauración rechazada")
            },
            execute("Recuperación de restauración parcial respeta cambios posteriores") {
                let f = try Fixture(); defer { f.dispose() }
                let second = f.sandbox.appendingPathComponent("data/second.bin")
                try Data("ORIGINAL-SEGUNDO".utf8).write(to: second)
                var p = f.project
                p.rules.append(PatchRule(bundleID: bundle,
                    relativePath: "data/second.bin", replacementFilename: "new.bin",
                    replacementData: Data("MODIFICADO-SEGUNDO".utf8)))
                let r = try PatchTransaction.apply(project: p, backupRoot: f.backups,
                    containerResolver: f.resolve)
                do {
                    _ = try PatchTransaction.restore(receipt: r, containerResolver: f.resolve,
                        beforeWrite: { index in
                            if index == 1 {
                                try Data("EXTERNO-DESPUES-DE-RESTABLECER".utf8).write(to: second)
                                throw PatchPackageError.restoreFailed
                            }
                        })
                    throw NSError(domain: "NEXORA.Test", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "No señaló fallo en recuperación parcial"])
                } catch PatchPackageError.restoreFailed { /* correcto */ }
                try require(String(data: try Data(contentsOf: second), encoding: .utf8)
                    == "EXTERNO-DESPUES-DE-RESTABLECER",
                    "Revirtió un cambio externo posterior a su propia escritura")
                try require(f.read() == "MODIFICADO", "Alteró un destino que aún no restauraba")
                try require(PatchTransaction.latestReceipt(projectID: p.id,
                    backupRoot: f.backups) != nil, "Perdió el diario de recuperación")
            },
            execute("Diario corrupto bloquea nueva activación sin pisar el original") {
                let f = try Fixture(original: "MI-ORIGINAL"); defer { f.dispose() }
                let folder = f.backups.appendingPathComponent(UUID().uuidString)
                    .appendingPathComponent(UUID().uuidString)
                try manager.createDirectory(at: folder, withIntermediateDirectories: true)
                let record = folder.appendingPathComponent("journal.plist")
                try Data("DIARIO-INVALIDO".utf8).write(to: record)
                do {
                    _ = try PatchTransaction.apply(project: f.project, backupRoot: f.backups,
                        containerResolver: f.resolve)
                    throw NSError(domain: "NEXORA.Test", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Permitió activar con historial corrupto"])
                } catch PatchPackageError.unverifiableJournal { /* protección correcta */ }
                try require(f.read() == "MI-ORIGINAL", "Se escribió sobre original durante error de diario")
                try manager.removeItem(at: folder)
                let receipt = try PatchTransaction.apply(project: f.project, backupRoot: f.backups,
                    containerResolver: f.resolve)
                try require(f.read() == "MODIFICADO", "No reanudó después de corregir historial")
                _ = try PatchTransaction.restore(receipt: receipt, containerResolver: f.resolve)
                try require(f.read() == "MI-ORIGINAL", "No restituyó original después de corregir historial")
            },
            execute("Activación concurrente de opciones no pisa el primer respaldo") {
                let f = try Fixture(original: "INICIAL"); defer { f.dispose() }
                let p2 = PatchProject(name: "alternativa", rules: [PatchRule(
                    bundleID: bundle, relativePath: "data/file.bin",
                    replacementFilename: "alternativa.bin", replacementData: Data("OTRO".utf8))])
                let group = DispatchGroup()
                let gate = DispatchSemaphore(value: 0)
                let receipts = ConcurrentReceiptBox()
                let projects = [f.project, p2]
                for project in projects {
                    group.enter()
                    DispatchQueue.global(qos: .userInitiated).async {
                        gate.wait()
                        if let receipt = try? PatchTransaction.apply(project: project,
                            backupRoot: f.backups, containerResolver: f.resolve) {
                            receipts.append((project.id, receipt))
                        }
                        group.leave()
                    }
                }
                gate.signal(); gate.signal()
                group.wait()
                let successful = receipts.snapshot()
                try require(successful.count == 1, "Dos activaciones competidoras tuvieron éxito")
                let appliedValue = successful[0].0 == f.project.id ? "MODIFICADO" : "OTRO"
                try require(f.read() == appliedValue, "Destino no coincide con la única activación")
                _ = try PatchTransaction.restore(receipt: successful[0].1, containerResolver: f.resolve)
                try require(f.read() == "INICIAL", "Restauración posterior a carrera no devolvió original")
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
