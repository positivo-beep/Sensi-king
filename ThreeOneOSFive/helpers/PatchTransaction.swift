import CryptoKit
import Darwin
import Foundation

struct PatchTransactionReceipt: Equatable, Identifiable {
    let id: UUID
    let projectID: UUID
    let journalURL: URL
}

enum PatchTargetChangeKind: Equatable {
    case modified
    case missing
}

struct PatchTargetChange: Equatable {
    let bundleID: String
    let relativePath: String
    let kind: PatchTargetChangeKind

    var displayPath: String {
        bundleID + "/" + relativePath
    }
}

struct PatchRestoreInspection: Equatable {
    let changedTargets: [PatchTargetChange]
}

enum PatchTransaction {
    /// Huella histórica de un original guardado ANTES de una activación.
    /// Solo se usan respaldos verificables que ya pertenecen a NEXORA.
    private struct PreviousOriginal {
        let digest: Data
        let byteCount: UInt64
        let createdAt: Date
        let replacementDigest: Data
    }

    private enum Status: String, Codable {
        case prepared
        case applied
        case rolledBack
        case restored
        // Un archivo externo reemplazó el modificado; conservarlo sin sobrescribir.
        // No implica que su origen sea oficial o verificado.
        case externalUpdatePreserved
    }

    private struct Record: Codable {
        let ruleID: UUID
        let bundleID: String
        let relativePath: String
        let containerFingerprint: Data
        let originalExisted: Bool
        let backupFilename: String?
        let originalDigest: Data?
        let replacementDigest: Data
        let appliedFilename: String?
    }

    private struct DirectoryRecord: Codable {
        let bundleID: String
        let relativePath: String
        let containerFingerprint: Data
    }

    private struct Journal: Codable {
        let schemaVersion: Int
        let transactionID: UUID
        let projectID: UUID
        let createdAt: Date
        var status: Status
        let records: [Record]
        let createdDirectories: [DirectoryRecord]?
    }

    private struct ResolvedRule {
        let rule: PatchRule
        let containerRoot: URL
        let target: URL
    }

    private struct ResolvedDirectory {
        let bundleID: String
        let relativePath: String
        let containerRoot: URL
        let target: URL
    }

    private struct ResolvedRecord {
        let record: Record
        let target: URL
    }

    private struct CurrentFileSnapshot {
        let target: URL
        let existed: Bool
        let snapshotURL: URL?
    }

    private enum WrittenTargetState {
        case present(Data)
        case absent
    }

    private enum AppliedSource {
        case file(URL)
        case data(Data)
    }

    private static let minimumSchemaVersion = 1
    private static let schemaVersion = 2
    private static let journalFilename = "journal.plist"

    // Serializa aplicar, restaurar y reactivar en el proceso actual.
    // Impide que dos botones simultáneos guarden respaldos incompatibles.
    private static let mutationLock = NSRecursiveLock()

    private static func withMutationLock<T>(_ operation: () throws -> T) rethrows -> T {
        mutationLock.lock()
        defer { mutationLock.unlock() }
        return try operation()
    }

    // Un diario corrupto no significa que un archivo esté restaurado.
    // Bloquear una nueva activación protege el original mientras se revisa el respaldo.
    private static func containsUnverifiableJournal(
        backupRoot: URL,
        fileManager: FileManager
    ) -> Bool {
        guard fileManager.fileExists(atPath: backupRoot.path) else { return false }
        guard let projects = try? fileManager.contentsOfDirectory(
            at: backupRoot, includingPropertiesForKeys: nil
        ) else { return true }
        for project in projects {
            guard let projectID = UUID(uuidString: project.lastPathComponent) else { continue }
            guard let transactions = try? fileManager.contentsOfDirectory(
                at: project, includingPropertiesForKeys: nil
            ) else { return true }
            for transaction in transactions {
                guard let transactionID = UUID(uuidString: transaction.lastPathComponent) else { continue }
                let url = transaction.appendingPathComponent(journalFilename)
                // Una preparación interrumpida ANTES de escribir el diario
                // no llega a ejecutar escrituras en los destinos.
                guard fileManager.fileExists(atPath: url.path) else { continue }
                guard let journal = try? readJournal(url),
                      (minimumSchemaVersion...schemaVersion).contains(journal.schemaVersion),
                      journal.projectID == projectID,
                      journal.transactionID == transactionID else { return true }
            }
        }
        return false
    }

    static func apply(
        project: PatchProject,
        backupRoot: URL,
        allowUpdatedOriginal: Bool = false,
        containerResolver: (String) throws -> URL,
        beforeWrite: ((Int) throws -> Void)? = nil,
        fileManager: FileManager = .default
    ) throws -> PatchTransactionReceipt {
        try withMutationLock {
            try applyExclusive(
                project: project,
                backupRoot: backupRoot,
                allowUpdatedOriginal: allowUpdatedOriginal,
                containerResolver: containerResolver,
                beforeWrite: beforeWrite,
                fileManager: fileManager
            )
        }
    }

    private static func applyExclusive(
        project: PatchProject,
        backupRoot: URL,
        allowUpdatedOriginal: Bool,
        containerResolver: (String) throws -> URL,
        beforeWrite: ((Int) throws -> Void)?,
        fileManager: FileManager
    ) throws -> PatchTransactionReceipt {
        guard !containsUnverifiableJournal(backupRoot: backupRoot, fileManager: fileManager) else {
            throw PatchPackageError.unverifiableJournal
        }
        guard !project.rules.isEmpty || !project.directories.isEmpty else {
            throw PatchPackageError.invalidProject
        }
        guard latestReceipt(
            projectID: project.id,
            backupRoot: backupRoot,
            fileManager: fileManager
        ) == nil else {
            throw PatchPackageError.projectAlreadyApplied
        }

        var roots: [String: URL] = [:]
        var resolvedRules: [ResolvedRule] = []
        var resolvedDirectories: [ResolvedDirectory] = []
        var targetKeys = Set<String>()

        func resolvedRoot(for bundleID: String) throws -> URL {
            if let cached = roots[bundleID] { return cached }
            let root = PatchPathValidator.canonicalFileURL(try containerResolver(bundleID))
            roots[bundleID] = root
            return root
        }

        var requestedDirectories = Set<String>()
        for directory in project.directories {
            let bundleID = try PatchPathValidator.canonicalBundleIdentifier(directory.bundleID)
            guard bundleID == directory.bundleID else { throw PatchPackageError.invalidProject }
            requestedDirectories.insert(bundleID + "\0" + directory.relativePath)
        }
        for rule in project.rules {
            let components = try PatchPathValidator.canonicalRelativePath(rule.relativePath)
                .split(separator: "/").map(String.init)
            guard components.count > 1 else { continue }
            for count in 1..<components.count {
                requestedDirectories.insert(
                    rule.bundleID + "\0" + components.prefix(count).joined(separator: "/")
                )
            }
        }

        for key in requestedDirectories.sorted(by: directoryKeySort) {
            let parts = key.split(separator: "\0", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { throw PatchPackageError.invalidProject }
            let bundleID = try PatchPathValidator.canonicalBundleIdentifier(String(parts[0]))
            let relativePath = try PatchPathValidator.canonicalRelativePath(String(parts[1]))
            let root = try resolvedRoot(for: bundleID)
            let target = try PatchPathValidator.resolveContainedTargetURL(
                relativePath: relativePath,
                containerRoot: root
            )
            try validateDirectoryTarget(
                target,
                relativePath: relativePath,
                containerRoot: root,
                fileManager: fileManager
            )
            resolvedDirectories.append(ResolvedDirectory(
                bundleID: bundleID,
                relativePath: relativePath,
                containerRoot: root,
                target: target
            ))
        }

        for rule in project.rules {
            let bundleID = try PatchPathValidator.canonicalBundleIdentifier(rule.bundleID)
            guard bundleID == rule.bundleID else { throw PatchPackageError.invalidProject }
            let root = try resolvedRoot(for: bundleID)
            let target = try PatchPathValidator.resolveContainedTargetURL(
                relativePath: rule.relativePath,
                containerRoot: root
            )
            let targetKey = target.path
            guard targetKeys.insert(targetKey).inserted else {
                throw PatchPackageError.duplicateTarget
            }
            try validateFileTarget(
                target,
                relativePath: rule.relativePath,
                containerRoot: root,
                allowMissingParents: true,
                fileManager: fileManager
            )
            resolvedRules.append(ResolvedRule(rule: rule, containerRoot: root, target: target))
        }

        let occupied = appliedTargetKeys(
            backupRoot: backupRoot,
            excludingProjectID: project.id,
            fileManager: fileManager
        )
        for resolved in resolvedRules {
            let occupancyKey = resolved.rule.bundleID + "\0" + resolved.rule.relativePath
            if occupied.contains(occupancyKey) {
                throw PatchPackageError.targetOccupied(
                    resolved.rule.bundleID + "/" + resolved.rule.relativePath
                )
            }
        }

        // Validar que cada reemplazo se haya preparado para la version ORIGINAL
        // seleccionada por el usuario. Nunca inferir compatibilidad solo por tamaño.
        // Un hash esperado incorrecto (o un original ausente) aborta sin cambios.
        var incompatible: [String] = []
        for item in resolvedRules {
            guard let expected = item.rule.expectedOriginalSHA256 else { continue }
            let label = item.rule.bundleID + "/" + item.rule.relativePath
            guard expected.count == 64,
                  expected.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                  fileManager.fileExists(atPath: item.target.path),
                  let actual = try? digestFile(item.target),
                  hexDigest(actual) == expected else {
                incompatible.append(label + ": original distinto al indicado en el paquete")
                continue
            }
        }
        if !incompatible.isEmpty {
            throw PatchPackageError.incompatibleOriginalVersion(incompatible)
        }

        // Detectar actualizaciones del ORIGINAL (contenido y tamaño) antes de
        // escribir un reemplazo. Un cambio no implica que sea oficial.
        let versionChanges = try changesSinceLastOriginal(
            resolvedRules,
            backupRoot: backupRoot,
            fileManager: fileManager
        )
        // Si ha cambiado el original, NO basta con que el usuario confirme.
        // Exigir un paquete actualizado con SHA-256 esperado de cada destino.
        // Una carga antigua sin referencia versionada debe detenerse.
        if !versionChanges.isEmpty {
            if versionChanges.contains(where: { $0.contains(": no se encuentra") }) {
                throw PatchPackageError.originalVersionChanged(versionChanges)
            }
            let allBound = resolvedRules.allSatisfy { $0.rule.expectedOriginalSHA256 != nil }
            if !allBound {
                throw PatchPackageError.updatedReplacementRequired(versionChanges)
            }
            // Rechazar reutilizar el mismo payload de la version anterior,
            // aunque se haya vinculado a un SHA nuevo.
            let oldIdentities = Dictionary(uniqueKeysWithValues: resolvedRules.map {
                ($0.rule.bundleID + "\0" + $0.rule.relativePath, containerFingerprint($0.containerRoot))
            })
            let historical = previousOriginalVersions(
                backupRoot: backupRoot, targetFingerprints: oldIdentities, fileManager: fileManager
            )
            var stale: [String] = []
            for item in resolvedRules {
                let key = item.rule.bundleID + "\0" + item.rule.relativePath
                if let older = historical[key],
                   digest(item.rule.replacementData) == older.replacementDigest {
                    stale.append(item.rule.bundleID + "/" + item.rule.relativePath)
                }
            }
            if !stale.isEmpty {
                throw PatchPackageError.updatedReplacementRequired(stale)
            }
        }
        // Compatibilidad de firma para codigo antiguo: allowUpdatedOriginal no
        // omite las protecciones, incluso si el llamador lo solicita.
        _ = allowUpdatedOriginal

        let transactionID = UUID()
        let transactionDirectory = backupRoot
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent(transactionID.uuidString, isDirectory: true)
        do {
            try fileManager.createDirectory(at: transactionDirectory, withIntermediateDirectories: true)
        } catch {
            throw PatchPackageError.applyFailed
        }

        var records: [Record] = []
        let createdDirectories = resolvedDirectories.compactMap { resolved -> DirectoryRecord? in
            guard !fileManager.fileExists(atPath: resolved.target.path) else { return nil }
            return DirectoryRecord(
                bundleID: resolved.bundleID,
                relativePath: resolved.relativePath,
                containerFingerprint: containerFingerprint(resolved.containerRoot)
            )
        }
        do {
            for resolved in resolvedRules {
                let existed = fileManager.fileExists(atPath: resolved.target.path)
                let backupFilename = existed ? "\(resolved.rule.id.uuidString).original" : nil
                let appliedFilename = project.isPrivate
                    ? nil
                    : "\(resolved.rule.id.uuidString).applied"
                var originalDigest: Data?
                if let backupFilename {
                    let backupURL = transactionDirectory.appendingPathComponent(backupFilename)
                    // Comprobar que la copia tiene los mismos bytes que el origen
                    // antes y después de copiar. Nunca aplicar si hubo cambios.
                    let originalDigestBefore = try digestFile(resolved.target)
                    try fileManager.copyItem(at: resolved.target, to: backupURL)
                    let backupDigest = try digestFile(backupURL)
                    guard backupDigest == originalDigestBefore,
                          try digestFile(resolved.target) == originalDigestBefore else {
                        throw PatchPackageError.applyFailed
                    }
                    originalDigest = backupDigest
                }
                let replacementDigest = digest(resolved.rule.replacementData)
                if let appliedFilename {
                    let appliedURL = transactionDirectory.appendingPathComponent(appliedFilename)
                    try resolved.rule.replacementData.write(to: appliedURL, options: .atomic)
                    guard try digestFile(appliedURL) == replacementDigest else {
                        throw PatchPackageError.applyFailed
                    }
                }
                records.append(Record(
                    ruleID: resolved.rule.id,
                    bundleID: resolved.rule.bundleID,
                    relativePath: resolved.rule.relativePath,
                    containerFingerprint: containerFingerprint(resolved.containerRoot),
                    originalExisted: existed,
                    backupFilename: backupFilename,
                    originalDigest: originalDigest,
                    replacementDigest: replacementDigest,
                    appliedFilename: appliedFilename
                ))
            }
        } catch let error as PatchPackageError {
            throw error
        } catch {
            throw PatchPackageError.applyFailed
        }

        let journalURL = transactionDirectory.appendingPathComponent(journalFilename)
        var journal = Journal(
            schemaVersion: schemaVersion,
            transactionID: transactionID,
            projectID: project.id,
            createdAt: Date(),
            status: .prepared,
            records: records,
            createdDirectories: createdDirectories
        )
        do {
            try writeJournal(journal, to: journalURL)
        } catch {
            throw PatchPackageError.applyFailed
        }

        // Registrar solo los destinos escritos realmente. Ante un cambio externo
        // durante la activación, jamás restaurar rutas que NEXORA no tocó.
        var writtenIndices: [Int] = []
        do {
            for resolved in resolvedDirectories where !fileManager.fileExists(atPath: resolved.target.path) {
                try fileManager.createDirectory(
                    at: resolved.target,
                    withIntermediateDirectories: false
                )
            }
            for (index, resolved) in resolvedRules.enumerated() {
                try beforeWrite?(index)
                // El original pudo actualizarse DESPUÉS de la comprobación
                // previa o mientras se preparaban los respaldos. Comprobarlo
                // inmediatamente antes de sustituirlo, incluido el caso en
                // que el destino no existía y otro proceso acaba de crearlo.
                try validateFileTarget(
                    resolved.target,
                    relativePath: resolved.rule.relativePath,
                    containerRoot: resolved.containerRoot,
                    allowMissingParents: false,
                    fileManager: fileManager
                )
                let record = records[index]
                let unchanged: Bool
                if record.originalExisted {
                    if fileManager.fileExists(atPath: resolved.target.path) {
                        unchanged = try digestFile(resolved.target) == record.originalDigest
                    } else {
                        unchanged = false
                    }
                } else {
                    unchanged = !fileManager.fileExists(atPath: resolved.target.path)
                }
                guard unchanged else {
                    throw PatchPackageError.incompatibleOriginalVersion([
                        resolved.rule.bundleID + "/" + resolved.rule.relativePath
                            + ": cambió durante la activación; no se sobrescribió"
                    ])
                }
                try atomicWrite(
                    resolved.rule.replacementData,
                    to: resolved.target,
                    preservingExistingAttributes: true,
                    fileManager: fileManager
                )
                writtenIndices.append(index)
                guard try digestFile(resolved.target) == record.replacementDigest else {
                    throw PatchPackageError.applyFailed
                }
            }
            journal.status = .applied
            try writeJournal(journal, to: journalURL)
            return PatchTransactionReceipt(
                id: transactionID,
                projectID: project.id,
                journalURL: journalURL
            )
        } catch {
            let originalError = error
            var rollbackComplete = true
            // Recuperar en orden inverso SOLO los destinos reemplazados.
            // Si otro proceso cambió uno de ellos, no se borra su trabajo:
            // se conserva el diario .prepared para recuperación supervisada.
            for index in writtenIndices.reversed() {
                let record = records[index]
                let target = resolvedRules[index].target
                do {
                    try validateFileTarget(
                        target,
                        relativePath: record.relativePath,
                        containerRoot: resolvedRules[index].containerRoot,
                        allowMissingParents: false,
                        fileManager: fileManager
                    )
                    guard fileManager.fileExists(atPath: target.path),
                          try digestFile(target) == record.replacementDigest else {
                        rollbackComplete = false
                        continue
                    }
                    if record.originalExisted {
                        guard let filename = record.backupFilename,
                              let expected = record.originalDigest else {
                            rollbackComplete = false
                            continue
                        }
                        let backup = transactionDirectory.appendingPathComponent(filename)
                        guard fileManager.fileExists(atPath: backup.path),
                              try digestFile(backup) == expected else {
                            rollbackComplete = false
                            continue
                        }
                        try atomicCopy(backup, to: target, fileManager: fileManager)
                        guard try digestFile(target) == expected else {
                            rollbackComplete = false
                            continue
                        }
                    } else {
                        try fileManager.removeItem(at: target)
                    }
                } catch {
                    rollbackComplete = false
                }
            }
            if rollbackComplete {
                journal.status = .rolledBack
                do {
                    try writeJournal(journal, to: journalURL)
                    let createdURLs = resolvedDirectories
                        .filter { directory in
                            createdDirectories.contains { record in
                                record.bundleID == directory.bundleID
                                    && record.relativePath == directory.relativePath
                            }
                        }
                        .map(\.target)
                    removeEmptyCreatedDirectories(createdURLs, fileManager: fileManager)
                } catch {
                    rollbackComplete = false
                }
            }
            guard rollbackComplete else {
                throw PatchPackageError.applyFailed
            }
            if let patchError = originalError as? PatchPackageError {
                throw patchError
            }
            throw PatchPackageError.applyFailed
        }
    }

    /// Busca el último respaldo original válido para cada ruta. Esto permite
    /// detectar cambios después de cerrar una opción sin crear registros nuevos.
    private static func previousOriginalVersions(
        backupRoot: URL,
        targetFingerprints: [String: Data],
        fileManager: FileManager
    ) -> [String: PreviousOriginal] {
        guard let projectFolders = try? fileManager.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [:] }

        var found: [String: PreviousOriginal] = [:]
        for projectFolder in projectFolders where UUID(uuidString: projectFolder.lastPathComponent) != nil {
            guard let transactionFolders = try? fileManager.contentsOfDirectory(
                at: projectFolder,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for folder in transactionFolders {
                guard let journal = try? readJournal(folder.appendingPathComponent(journalFilename)),
                      journal.status == .restored || journal.status == .applied || journal.status == .externalUpdatePreserved,
                      (minimumSchemaVersion...schemaVersion).contains(journal.schemaVersion)
                else { continue }
                for record in journal.records {
                    let key = record.bundleID + "\0" + record.relativePath
                    guard let expectedFingerprint = targetFingerprints[key],
                          expectedFingerprint == record.containerFingerprint,
                          let backedUpDigest = record.originalDigest,
                          let backupFilename = record.backupFilename
                    else { continue }
                    if let current = found[key], current.createdAt >= journal.createdAt { continue }
                    let backup = folder.appendingPathComponent(backupFilename)
                    guard fileManager.fileExists(atPath: backup.path),
                          let attrs = try? fileManager.attributesOfItem(atPath: backup.path),
                          let size = (attrs[.size] as? NSNumber)?.uint64Value,
                          let digest = try? digestFile(backup),
                          digest == backedUpDigest else { continue }
                    found[key] = PreviousOriginal(
                        digest: backedUpDigest,
                        byteCount: size,
                        createdAt: journal.createdAt,
                        replacementDigest: record.replacementDigest
                    )
                }
            }
        }
        return found
    }

    private static func hexDigest(_ digest: Data) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func changesSinceLastOriginal(
        _ resolvedRules: [ResolvedRule],
        backupRoot: URL,
        fileManager: FileManager
    ) throws -> [String] {
        let identities = Dictionary(uniqueKeysWithValues: resolvedRules.map { resolved in
            (resolved.rule.bundleID + "\0" + resolved.rule.relativePath,
             containerFingerprint(resolved.containerRoot))
        })
        let old = previousOriginalVersions(
            backupRoot: backupRoot,
            targetFingerprints: identities,
            fileManager: fileManager
        )
        var changes: [String] = []
        for item in resolvedRules {
            let key = item.rule.bundleID + "\0" + item.rule.relativePath
            guard let previous = old[key] else { continue }
            let name = item.rule.bundleID + "/" + item.rule.relativePath
            guard fileManager.fileExists(atPath: item.target.path) else {
                changes.append("\(name): no se encuentra (antes: \(previous.byteCount) bytes)")
                continue
            }
            let attrs = try fileManager.attributesOfItem(atPath: item.target.path)
            guard let size = (attrs[.size] as? NSNumber)?.uint64Value else {
                throw PatchPackageError.applyFailed
            }
            let digest = try digestFile(item.target)
            if size != previous.byteCount || digest != previous.digest {
                let detail = size == previous.byteCount
                    ? "mismo tamaño, contenido SHA-256 diferente"
                    : "tamaño: \(previous.byteCount) → \(size) bytes; SHA-256 revisado"
                changes.append("\(name): \(detail)")
            }
        }
        return changes
    }

    static func inspectRestore(
        receipt: PatchTransactionReceipt,
        containerResolver: (String) throws -> URL,
        fileManager: FileManager = .default
    ) throws -> PatchRestoreInspection {
        do {
            let journal = try activeJournal(for: receipt)
            guard journal.status == .applied else {
                return PatchRestoreInspection(changedTargets: [])
            }
            let roots = try resolvedRoots(
                journal: journal,
                containerResolver: containerResolver
            )
            let resolved = try resolvedRecords(
                journal.records,
                transactionDirectory: receipt.journalURL.deletingLastPathComponent(),
                roots: roots,
                fileManager: fileManager
            )
            return PatchRestoreInspection(
                changedTargets: try changedTargets(in: resolved, fileManager: fileManager)
            )
        } catch {
            throw PatchPackageError.restoreFailed
        }
    }

    /// Restaura los archivos que aún contienen el reemplazo de NEXORA.
    /// En modo de conservación, un archivo externo que cambió después de aplicar
    /// la opción no se sobrescribe. NO se presume que sea una actualización oficial.
    @discardableResult
    static func restore(
        receipt: PatchTransactionReceipt,
        allowChangedTargets: Bool = false,
        preserveExternallyChangedTargets: Bool = false,
        containerResolver: (String) throws -> URL,
        beforeWrite: ((Int) throws -> Void)? = nil,
        fileManager: FileManager = .default
    ) throws -> [String] {
        try withMutationLock {
            try restoreExclusive(
                receipt: receipt,
                allowChangedTargets: allowChangedTargets,
                preserveExternallyChangedTargets: preserveExternallyChangedTargets,
                containerResolver: containerResolver,
                beforeWrite: beforeWrite,
                fileManager: fileManager
            )
        }
    }

    private static func restoreExclusive(
        receipt: PatchTransactionReceipt,
        allowChangedTargets: Bool,
        preserveExternallyChangedTargets: Bool,
        containerResolver: (String) throws -> URL,
        beforeWrite: ((Int) throws -> Void)?,
        fileManager: FileManager
    ) throws -> [String] {
        do {
            var journal = try activeJournal(for: receipt)
            let transactionDirectory = receipt.journalURL.deletingLastPathComponent()
            let roots = try resolvedRoots(
                journal: journal,
                containerResolver: containerResolver
            )
            let resolved = try resolvedRecords(
                journal.records,
                transactionDirectory: transactionDirectory,
                roots: roots,
                allowMissingParents: journal.status == .prepared,
                fileManager: fileManager
            )
            // Una transacción .prepared puede ser una escritura interrumpida.
            // Nunca suponer que todos sus destinos contienen el reemplazo:
            // solo es seguro restaurar desde el respaldo cuando vemos
            // exactamente el original registrado o el payload de NEXORA.
            if journal.status == .prepared {
                var unknownPreparedTargets: [String] = []
                for item in resolved {
                    let name = item.record.bundleID + "/" + item.record.relativePath
                    if fileManager.fileExists(atPath: item.target.path) {
                        let current = try digestFile(item.target)
                        if current != item.record.replacementDigest
                            && current != item.record.originalDigest {
                            unknownPreparedTargets.append(name)
                        }
                    } else if item.record.originalExisted {
                        unknownPreparedTargets.append(name)
                    }
                }
                if !unknownPreparedTargets.isEmpty {
                    throw PatchPackageError.restoreTargetsChanged(unknownPreparedTargets)
                }
            }
            let changes = journal.status == .applied
                ? try changedTargets(in: resolved, fileManager: fileManager)
                : []
            // Un destino ausente NO equivale a una actualización: detenerse.
            // Se conserva el respaldo para recuperación manual.
            let missing = changes.filter { $0.kind == .missing }
            if !missing.isEmpty && !allowChangedTargets {
                throw PatchPackageError.restoreTargetsChanged(missing.map(\.displayPath))
            }
            if !changes.isEmpty && !allowChangedTargets && !preserveExternallyChangedTargets {
                throw PatchPackageError.restoreTargetsChanged(changes.map(\.displayPath))
            }
            let preservedChanges: [PatchTargetChange] =
                preserveExternallyChangedTargets && !allowChangedTargets
                ? changes.filter { $0.kind == .modified } : []
            let preservedPaths = Set(preservedChanges.map(\.displayPath))
            // Guardar digest de cada cambio externo para detectar carreras mientras
            // se restauran los demás archivos. Un digest no prueba autenticidad.
            var preservedDigests: [String: Data] = [:]
            for item in resolved where preservedPaths.contains(item.record.bundleID + "/" + item.record.relativePath) {
                preservedDigests[item.target.path] = try digestFile(item.target)
            }
            let createdDirectoryURLs = try resolvedCreatedDirectories(
                journal.createdDirectories ?? [],
                roots: roots,
                fileManager: fileManager
            )

            try withCurrentStateRecovery(
                resolved,
                transactionDirectory: transactionDirectory,
                fileManager: fileManager
            ) { markWritten in
                for (index, item) in resolved.reversed().enumerated() {
                    try beforeWrite?(index)
                    if let expected = preservedDigests[item.target.path] {
                        // El juego u otra aplicación cambió el contenido. No escribir
                        // por encima y comprobar que no cambie durante el proceso.
                        guard fileManager.fileExists(atPath: item.target.path),
                              try digestFile(item.target) == expected else {
                            throw PatchPackageError.restoreFailed
                        }
                        continue
                    }
                    // Evitar sobrescribir un reemplazo modificado después de
                    // inspeccionarlo y antes de restaurarlo.
                    if !allowChangedTargets {
                        let exists = fileManager.fileExists(atPath: item.target.path)
                        let now = exists ? try digestFile(item.target) : nil
                        let isPatched = now == item.record.replacementDigest
                        let isPreparedOriginal = journal.status == .prepared
                            && ((item.record.originalExisted && now == item.record.originalDigest)
                                || (!item.record.originalExisted && !exists))
                        guard isPatched || isPreparedOriginal else {
                            throw PatchPackageError.restoreTargetsChanged([
                                item.record.bundleID + "/" + item.record.relativePath
                            ])
                        }
                        if isPreparedOriginal { continue }
                    }
                    if item.record.originalExisted {
                        let backup = transactionDirectory.appendingPathComponent(
                            item.record.backupFilename!
                        )
                        try atomicCopy(backup, to: item.target, fileManager: fileManager)
                        markWritten(item.target, item.record.originalDigest)
                    } else if fileManager.fileExists(atPath: item.target.path) {
                        try fileManager.removeItem(at: item.target)
                        markWritten(item.target, nil)
                    }
                }
                // Confirmar la restauración ANTES de marcar la transacción como cerrada.
                // Si la comprobación falla, withCurrentStateRecovery revierte la operación.
                try verifyRestoredContent(
                    resolved.filter { preservedDigests[$0.target.path] == nil },
                    fileManager: fileManager
                )
                for (path, expected) in preservedDigests {
                    guard fileManager.fileExists(atPath: path),
                          try digestFile(URL(fileURLWithPath: path)) == expected else {
                        throw PatchPackageError.restoreFailed
                    }
                }
                journal.status = preservedDigests.isEmpty ? .restored : .externalUpdatePreserved
                try writeJournal(journal, to: receipt.journalURL)
            }

            removeEmptyCreatedDirectories(createdDirectoryURLs, fileManager: fileManager)
            return preservedChanges.map(\.displayPath)
        } catch let error as PatchPackageError {
            if case .restoreTargetsChanged = error { throw error }
            throw PatchPackageError.restoreFailed
        } catch {
            throw PatchPackageError.restoreFailed
        }
    }

    static func resetToAppliedState(
        receipt: PatchTransactionReceipt,
        fallbackProject: PatchProject? = nil,
        containerResolver: (String) throws -> URL,
        beforeWrite: ((Int) throws -> Void)? = nil,
        fileManager: FileManager = .default
    ) throws {
        try withMutationLock {
            try resetExclusive(
                receipt: receipt,
                fallbackProject: fallbackProject,
                containerResolver: containerResolver,
                beforeWrite: beforeWrite,
                fileManager: fileManager
            )
        }
    }

    private static func resetExclusive(
        receipt: PatchTransactionReceipt,
        fallbackProject: PatchProject?,
        containerResolver: (String) throws -> URL,
        beforeWrite: ((Int) throws -> Void)?,
        fileManager: FileManager
    ) throws {
        do {
            let journal = try activeJournal(for: receipt)
            guard journal.status == .applied else {
                throw PatchPackageError.resetFailed
            }
            let transactionDirectory = receipt.journalURL.deletingLastPathComponent()
            let roots = try resolvedRoots(
                journal: journal,
                containerResolver: containerResolver
            )
            let resolved = try resolvedRecords(
                journal.records,
                transactionDirectory: transactionDirectory,
                roots: roots,
                fileManager: fileManager
            )
            let fallbackRules = Dictionary(
                uniqueKeysWithValues: (fallbackProject?.rules ?? []).map { ($0.id, $0) }
            )
            let sources = try resolved.map { item -> AppliedSource in
                if let filename = item.record.appliedFilename {
                    let source = transactionDirectory.appendingPathComponent(filename)
                    guard fileManager.fileExists(atPath: source.path),
                          try digestFile(source) == item.record.replacementDigest else {
                        throw PatchPackageError.resetFailed
                    }
                    return .file(source)
                }
                guard let rule = fallbackRules[item.record.ruleID],
                      rule.bundleID == item.record.bundleID,
                      rule.relativePath == item.record.relativePath,
                      digest(rule.replacementData) == item.record.replacementDigest else {
                    throw PatchPackageError.resetFailed
                }
                return .data(rule.replacementData)
            }

            try withCurrentStateRecovery(
                resolved,
                transactionDirectory: transactionDirectory,
                fileManager: fileManager
            ) { markWritten in
                for (index, item) in resolved.enumerated() {
                    try beforeWrite?(index)
                    switch sources[index] {
                    case .file(let source):
                        try atomicCopy(
                            source,
                            to: item.target,
                            preservingExistingAttributes: true,
                            fileManager: fileManager
                        )
                    case .data(let data):
                        try atomicWrite(
                            data,
                            to: item.target,
                            preservingExistingAttributes: true,
                            fileManager: fileManager
                        )
                    }
                    markWritten(item.target, item.record.replacementDigest)
                    guard try digestFile(item.target) == item.record.replacementDigest else {
                        throw PatchPackageError.resetFailed
                    }
                }
            }
        } catch {
            throw PatchPackageError.resetFailed
        }
    }

    static func latestReceipt(
        projectID: UUID,
        backupRoot: URL,
        fileManager: FileManager = .default
    ) -> PatchTransactionReceipt? {
        let projectDirectory = backupRoot.appendingPathComponent(projectID.uuidString, isDirectory: true)
        guard let directories = try? fileManager.contentsOfDirectory(
            at: projectDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        return directories.compactMap { directory -> (Journal, URL)? in
            let url = directory.appendingPathComponent(journalFilename)
            guard let journal = try? readJournal(url),
                  (minimumSchemaVersion...schemaVersion).contains(journal.schemaVersion),
                  journal.status == .applied || journal.status == .prepared else { return nil }
            return (journal, url)
        }
        .sorted { $0.0.createdAt > $1.0.createdAt }
        .first
        .map {
            PatchTransactionReceipt(
                id: $0.0.transactionID,
                projectID: $0.0.projectID,
                journalURL: $0.1
            )
        }
    }

    static func appliedTargetKeys(
        backupRoot: URL,
        excludingProjectID: UUID? = nil,
        fileManager: FileManager = .default
    ) -> Set<String> {
        guard let projectDirectories = try? fileManager.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var keys = Set<String>()
        for directory in projectDirectories {
            guard let projectID = UUID(uuidString: directory.lastPathComponent),
                  projectID != excludingProjectID,
                  let receipt = latestReceipt(
                    projectID: projectID,
                    backupRoot: backupRoot,
                    fileManager: fileManager
                  ),
                  let journal = try? readJournal(receipt.journalURL),
                  journal.status == .applied || journal.status == .prepared
            else { continue }
            for record in journal.records {
                keys.insert(record.bundleID + "\0" + record.relativePath)
            }
        }
        return keys
    }

    static func requiredBundleIdentifiers(for receipt: PatchTransactionReceipt) throws -> [String] {
        let journal = try readJournal(receipt.journalURL)
        guard (minimumSchemaVersion...schemaVersion).contains(journal.schemaVersion),
              journal.transactionID == receipt.id,
              journal.projectID == receipt.projectID else {
            throw PatchPackageError.restoreFailed
        }
        var seen = Set<String>()
        return (journal.records.map(\.bundleID)
            + (journal.createdDirectories ?? []).map(\.bundleID)).compactMap { bundleID in
                seen.insert(bundleID).inserted ? bundleID : nil
            }
    }

    private static func activeJournal(for receipt: PatchTransactionReceipt) throws -> Journal {
        let journal = try readJournal(receipt.journalURL)
        guard (minimumSchemaVersion...schemaVersion).contains(journal.schemaVersion),
              journal.transactionID == receipt.id,
              journal.projectID == receipt.projectID,
              journal.status == .applied || journal.status == .prepared else {
            throw PatchPackageError.restoreFailed
        }
        return journal
    }

    private static func resolvedRoots(
        journal: Journal,
        containerResolver: (String) throws -> URL
    ) throws -> [String: URL] {
        var roots: [String: URL] = [:]
        let identities = journal.records.map { ($0.bundleID, $0.containerFingerprint) }
            + (journal.createdDirectories ?? []).map { ($0.bundleID, $0.containerFingerprint) }
        for (bundleID, expectedFingerprint) in identities {
            if let root = roots[bundleID] {
                guard containerFingerprint(root) == expectedFingerprint else {
                    throw PatchPackageError.restoreFailed
                }
                continue
            }
            let root = PatchPathValidator.canonicalFileURL(try containerResolver(bundleID))
            guard containerFingerprint(root) == expectedFingerprint else {
                throw PatchPackageError.restoreFailed
            }
            roots[bundleID] = root
        }
        return roots
    }

    private static func resolvedRecords(
        _ records: [Record],
        transactionDirectory: URL,
        roots: [String: URL],
        allowMissingParents: Bool = false,
        fileManager: FileManager
    ) throws -> [ResolvedRecord] {
        try records.map { record in
            guard let root = roots[record.bundleID],
                  containerFingerprint(root) == record.containerFingerprint else {
                throw PatchPackageError.restoreFailed
            }
            let target = try PatchPathValidator.resolveContainedTargetURL(
                relativePath: record.relativePath,
                containerRoot: root
            )
            try validateFileTarget(
                target,
                relativePath: record.relativePath,
                containerRoot: root,
                allowMissingParents: allowMissingParents,
                fileManager: fileManager
            )
            if record.originalExisted {
                guard let backupFilename = record.backupFilename,
                      let expectedDigest = record.originalDigest else {
                    throw PatchPackageError.restoreFailed
                }
                let backup = transactionDirectory.appendingPathComponent(backupFilename)
                guard fileManager.fileExists(atPath: backup.path),
                      try digestFile(backup) == expectedDigest else {
                    throw PatchPackageError.restoreFailed
                }
            }
            return ResolvedRecord(record: record, target: target)
        }
    }

    private static func changedTargets(
        in resolved: [ResolvedRecord],
        fileManager: FileManager
    ) throws -> [PatchTargetChange] {
        try resolved.compactMap { item in
            guard fileManager.fileExists(atPath: item.target.path) else {
                return PatchTargetChange(
                    bundleID: item.record.bundleID,
                    relativePath: item.record.relativePath,
                    kind: .missing
                )
            }
            guard try digestFile(item.target) != item.record.replacementDigest else {
                return nil
            }
            return PatchTargetChange(
                bundleID: item.record.bundleID,
                relativePath: item.record.relativePath,
                kind: .modified
            )
        }
    }

    /// Comprueba el resultado real: los archivos anteriores deben coincidir byte a byte
    /// con su respaldo SHA-256 y los archivos creados por la opción deben desaparecer.
    /// Se ejecuta antes de registrar una restauración como exitosa.
    private static func verifyRestoredContent(
        _ records: [ResolvedRecord],
        fileManager: FileManager
    ) throws {
        for item in records {
            if item.record.originalExisted {
                guard let expected = item.record.originalDigest,
                      fileManager.fileExists(atPath: item.target.path),
                      try digestFile(item.target) == expected else {
                    throw PatchPackageError.restoreFailed
                }
            } else if fileManager.fileExists(atPath: item.target.path) {
                throw PatchPackageError.restoreFailed
            }
        }
    }

    private static func resolvedCreatedDirectories(
        _ directories: [DirectoryRecord],
        roots: [String: URL],
        fileManager: FileManager
    ) throws -> [URL] {
        try directories.map { directory in
            guard let root = roots[directory.bundleID],
                  containerFingerprint(root) == directory.containerFingerprint else {
                throw PatchPackageError.restoreFailed
            }
            let target = try PatchPathValidator.resolveContainedTargetURL(
                relativePath: directory.relativePath,
                containerRoot: root
            )
            if fileManager.fileExists(atPath: target.path) {
                let values = try target.resourceValues(
                    forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
                )
                guard values.isSymbolicLink != true, values.isDirectory == true else {
                    throw PatchPackageError.restoreFailed
                }
            }
            return target
        }
    }

    private static func withCurrentStateRecovery(
        _ resolved: [ResolvedRecord],
        transactionDirectory: URL,
        fileManager: FileManager,
        operation: (_ markWritten: (URL, Data?) -> Void) throws -> Void
    ) throws {
        let recoveryDirectory = transactionDirectory.appendingPathComponent(
            ".recovery-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: false)
        var snapshots: [CurrentFileSnapshot] = []
        do {
            for (index, item) in resolved.enumerated() {
                guard fileManager.fileExists(atPath: item.target.path) else {
                    snapshots.append(CurrentFileSnapshot(
                        target: item.target,
                        existed: false,
                        snapshotURL: nil
                    ))
                    continue
                }
                let snapshotURL = recoveryDirectory.appendingPathComponent("\(index).current")
                try fileManager.copyItem(at: item.target, to: snapshotURL)
                guard try digestFile(snapshotURL) == digestFile(item.target) else {
                    throw PatchPackageError.restoreFailed
                }
                snapshots.append(CurrentFileSnapshot(
                    target: item.target,
                    existed: true,
                    snapshotURL: snapshotURL
                ))
            }
        } catch {
            try? fileManager.removeItem(at: recoveryDirectory)
            throw error
        }

        var written: [String: WrittenTargetState] = [:]
        do {
            try operation { target, digest in
                written[target.path] = digest.map(WrittenTargetState.present) ?? .absent
            }
        } catch {
            let originalError = error
            var incomplete = false
            // El error puede ocurrir ANTES de escribir. Nunca revertir una
            // ruta que no marcamos como escrita, porque pudo actualizarse.
            for snapshot in snapshots.reversed() {
                guard let state = written[snapshot.target.path] else { continue }
                do {
                    switch state {
                    case .present(let digest):
                        guard fileManager.fileExists(atPath: snapshot.target.path),
                              try digestFile(snapshot.target) == digest else {
                            incomplete = true
                            continue
                        }
                    case .absent:
                        guard !fileManager.fileExists(atPath: snapshot.target.path) else {
                            incomplete = true
                            continue
                        }
                    }
                    if snapshot.existed, let snapshotURL = snapshot.snapshotURL {
                        try atomicCopy(snapshotURL, to: snapshot.target, fileManager: fileManager)
                    } else if fileManager.fileExists(atPath: snapshot.target.path) {
                        try fileManager.removeItem(at: snapshot.target)
                    }
                } catch {
                    incomplete = true
                }
            }
            if incomplete {
                // Conservar instantáneas por si la recuperación manual es necesaria.
                throw PatchPackageError.restoreFailed
            }
            try? fileManager.removeItem(at: recoveryDirectory)
            throw originalError
        }
        try? fileManager.removeItem(at: recoveryDirectory)
    }

    private static func removeEmptyCreatedDirectories(
        _ directories: [URL],
        fileManager: FileManager
    ) {
        for directory in directories.reversed() {
            guard fileManager.fileExists(atPath: directory.path),
                  let values = try? directory.resourceValues(
                    forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
                  ),
                  values.isSymbolicLink != true,
                  values.isDirectory == true,
                  let contents = try? fileManager.contentsOfDirectory(atPath: directory.path),
                  contents.isEmpty else { continue }
            try? fileManager.removeItem(at: directory)
        }
    }

    private static func restoreRecords(
        _ records: [Record],
        transactionDirectory: URL,
        roots: [String: URL],
        requirePatchedDigest: Bool,
        createdDirectories: [DirectoryRecord],
        fileManager: FileManager
    ) throws {
        var resolvedTargets: [(Record, URL)] = []
        for record in records {
            guard let root = roots[record.bundleID],
                  containerFingerprint(root) == record.containerFingerprint else {
                throw PatchPackageError.restoreFailed
            }
            let target = try PatchPathValidator.resolveContainedTargetURL(
                relativePath: record.relativePath,
                containerRoot: root
            )
            try validateFileTarget(
                target,
                relativePath: record.relativePath,
                containerRoot: root,
                allowMissingParents: !requirePatchedDigest,
                fileManager: fileManager
            )

            if requirePatchedDigest {
                guard fileManager.fileExists(atPath: target.path),
                      try digestFile(target) == record.replacementDigest else {
                    throw PatchPackageError.restoreFailed
                }
            }
            if record.originalExisted {
                guard let backupFilename = record.backupFilename,
                      let expectedDigest = record.originalDigest else {
                    throw PatchPackageError.restoreFailed
                }
                let backup = transactionDirectory.appendingPathComponent(backupFilename)
                guard fileManager.fileExists(atPath: backup.path),
                      try digestFile(backup) == expectedDigest else {
                    throw PatchPackageError.restoreFailed
                }
            }
            resolvedTargets.append((record, target))
        }

        for (record, target) in resolvedTargets.reversed() {
            if record.originalExisted {
                let backup = transactionDirectory.appendingPathComponent(record.backupFilename!)
                try atomicCopy(backup, to: target, fileManager: fileManager)
            } else if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
        }

        for directory in createdDirectories.reversed() {
            guard let root = roots[directory.bundleID],
                  containerFingerprint(root) == directory.containerFingerprint else {
                throw PatchPackageError.restoreFailed
            }
            let target = try PatchPathValidator.resolveContainedTargetURL(
                relativePath: directory.relativePath,
                containerRoot: root
            )
            guard fileManager.fileExists(atPath: target.path) else { continue }
            let values = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isDirectory == true else {
                throw PatchPackageError.restoreFailed
            }
            let contents = try fileManager.contentsOfDirectory(atPath: target.path)
            if contents.isEmpty {
                try fileManager.removeItem(at: target)
            }
        }
    }

    private static func validateFileTarget(
        _ target: URL,
        relativePath: String,
        containerRoot: URL,
        allowMissingParents: Bool,
        fileManager: FileManager
    ) throws {
        let components = try PatchPathValidator.canonicalRelativePath(relativePath)
            .split(separator: "/")
            .map(String.init)
        var cursor = PatchPathValidator.canonicalFileURL(containerRoot)
        for component in components.dropLast() {
            cursor.appendPathComponent(component, isDirectory: true)
            guard fileManager.fileExists(atPath: cursor.path) else {
                if allowMissingParents { break }
                throw PatchPackageError.applyFailed
            }
            let values = try cursor.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw PatchPackageError.symbolicLinkUnsupported
            }
            guard values.isDirectory == true else {
                throw PatchPackageError.applyFailed
            }
        }
        if fileManager.fileExists(atPath: target.path) {
            let values = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw PatchPackageError.symbolicLinkUnsupported
            }
            guard values.isDirectory != true else {
                throw PatchPackageError.applyFailed
            }
        }
    }

    private static func validateDirectoryTarget(
        _ target: URL,
        relativePath: String,
        containerRoot: URL,
        fileManager: FileManager
    ) throws {
        let components = try PatchPathValidator.canonicalRelativePath(relativePath)
            .split(separator: "/").map(String.init)
        var cursor = PatchPathValidator.canonicalFileURL(containerRoot)
        for component in components {
            cursor.appendPathComponent(component, isDirectory: true)
            guard fileManager.fileExists(atPath: cursor.path) else { break }
            let values = try cursor.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw PatchPackageError.symbolicLinkUnsupported
            }
            guard values.isDirectory == true else {
                throw PatchPackageError.applyFailed
            }
        }
        if fileManager.fileExists(atPath: target.path) {
            let values = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isDirectory == true else {
                throw PatchPackageError.applyFailed
            }
        }
    }

    private static func directoryKeySort(_ lhs: String, _ rhs: String) -> Bool {
        let leftDepth = lhs.filter { $0 == "/" }.count
        let rightDepth = rhs.filter { $0 == "/" }.count
        return leftDepth == rightDepth ? lhs < rhs : leftDepth < rightDepth
    }

    private static func atomicWrite(
        _ data: Data,
        to target: URL,
        preservingExistingAttributes: Bool,
        fileManager: FileManager
    ) throws {
        let staging = target.deletingLastPathComponent()
            .appendingPathComponent(".3105-patch-\(UUID().uuidString)")
        var attributes: [FileAttributeKey: Any] = [:]
        if preservingExistingAttributes,
           let current = try? fileManager.attributesOfItem(atPath: target.path) {
            if let permissions = current[.posixPermissions] { attributes[.posixPermissions] = permissions }
            if let protection = current[.protectionKey] { attributes[.protectionKey] = protection }
        }
        guard fileManager.createFile(atPath: staging.path, contents: data, attributes: attributes) else {
            throw PatchPackageError.applyFailed
        }
        defer { try? fileManager.removeItem(at: staging) }
        let handle = try FileHandle(forWritingTo: staging)
        try handle.synchronize()
        try handle.close()
        guard rename(staging.path, target.path) == 0 else {
            throw PatchPackageError.applyFailed
        }
    }

    private static func atomicCopy(
        _ source: URL,
        to target: URL,
        preservingExistingAttributes: Bool = false,
        fileManager: FileManager
    ) throws {
        let staging = target.deletingLastPathComponent()
            .appendingPathComponent(".3105-restore-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.copyItem(at: source, to: staging)
        if preservingExistingAttributes,
           let current = try? fileManager.attributesOfItem(atPath: target.path) {
            var attributes: [FileAttributeKey: Any] = [:]
            if let permissions = current[.posixPermissions] {
                attributes[.posixPermissions] = permissions
            }
            if let protection = current[.protectionKey] {
                attributes[.protectionKey] = protection
            }
            if !attributes.isEmpty {
                try fileManager.setAttributes(attributes, ofItemAtPath: staging.path)
            }
        }
        let handle = try FileHandle(forWritingTo: staging)
        try handle.synchronize()
        try handle.close()
        guard rename(staging.path, target.path) == 0 else {
            throw PatchPackageError.restoreFailed
        }
    }

    private static func writeJournal(_ journal: Journal, to url: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(journal).write(to: url, options: .atomic)
    }

    private static func readJournal(_ url: URL) throws -> Journal {
        try PropertyListDecoder().decode(Journal.self, from: Data(contentsOf: url))
    }

    private static func digest(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    private static func digestFile(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize())
    }

    private static func containerFingerprint(_ url: URL) -> Data {
        digest(Data(PatchPathValidator.canonicalFileURL(url).path.utf8))
    }
}
