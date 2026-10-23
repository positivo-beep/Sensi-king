import Foundation

struct NXTemporaryCleanupOutcome {
    let removedEntries: Int
    let warning: String?
    let preservedChangedFiles: [String]
}

enum DevicePatchService {
    static func apply(
        project: PatchProject,
        verifiedOriginals: [UUID: Data] = [:]
    ) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        do {
            return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
                try PatchTransaction.apply(
                    project: project,
                    backupRoot: try PatchProjectLibrary.backupRootURL(),
                    verifiedOriginals: verifiedOriginals,
                    containerResolver: { bundleID in
                        guard let root = roots[bundleID] else {
                            throw PatchPackageError.targetAppUnavailable(bundleID)
                        }
                        return root
                    }
                )
            }
        } catch {
            // Solo limpiar los temporales propios de esta opción cuando falla.
            // Nunca tocar los respaldos, diarios ni los archivos de otra app.
            _ = try? NXOwnedTemporaryWorkspaces.clean(optionID: project.id)
            throw error
        }
    }

    /// Comprobación al volver al primer plano. Solo inspecciona destinos
    /// legalmente resolubles; jamás modifica archivos ajenos.
    static func auditKnownOriginals(bundleID: String, relativePaths: [String]) throws -> [String] {
        try withResolvedContainers(bundleIDs: [bundleID]) { roots in
            guard let root = roots[bundleID] else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            return try PatchTransaction.observeAccessibleOriginals(
                bundleID: bundleID, relativePaths: relativePaths,
                containerRoot: root, backupRoot: try PatchProjectLibrary.backupRootURL()
            )
        }
    }

    static func inspectRestore(receipt: PatchTransactionReceipt) throws -> PatchRestoreInspection {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.inspectRestore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    /// Devuelve el resultado de limpieza de temporales propios de NEXORA.
    /// No mezcla errores de limpieza de caché con el resultado de la restauración.
    @discardableResult
    static func restore(
        receipt: PatchTransactionReceipt,
        allowChangedTargets: Bool = false,
        preserveExternallyChangedTargets: Bool = false
    ) throws -> NXTemporaryCleanupOutcome {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        let preserved = try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                allowChangedTargets: allowChangedTargets,
                preserveExternallyChangedTargets: preserveExternallyChangedTargets,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
        // Solo después de una restauración exitosa; jamás borrar respaldos ni registros.
        do {
            let removed = try NXOwnedTemporaryWorkspaces.clean(optionID: receipt.projectID)
            let warning = preserved.isEmpty ? nil :
                "NEXORA conservó \(preserved.count) archivo(s) que cambiaron externamente. " +
                "No sustituyó la versión nueva con el respaldo antiguo. " +
                "Su procedencia NO se ha verificado; revísala antes de volver a aplicar una opción."
            return NXTemporaryCleanupOutcome(
                removedEntries: removed,
                warning: warning,
                preservedChangedFiles: preserved
            )
        } catch {
            return NXTemporaryCleanupOutcome(
                removedEntries: 0,
                warning: "Restauración terminada, pero no se pudo limpiar la caché propia: \(error.localizedDescription)" +
                    (preserved.isEmpty ? "" : ". NEXORA conservó \(preserved.count) archivo(s) cambiados externamente; procedencia sin verificar"),
                preservedChangedFiles: preserved
            )
        }
    }

    static func resetToAppliedState(
        receipt: PatchTransactionReceipt,
        project: PatchProject
    ) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.resetToAppliedState(
                receipt: receipt,
                fallbackProject: project,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return nil }
        return PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)
    }

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]

        for bundleID in bundleIDs {
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}
