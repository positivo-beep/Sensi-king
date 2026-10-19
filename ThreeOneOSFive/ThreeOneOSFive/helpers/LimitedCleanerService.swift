import Foundation
import Darwin

struct LimitedCleanerUsage: Equatable {
    let cacheBytes: Int64
    let temporaryBytes: Int64
    let removableItemCount: Int

    static let empty = LimitedCleanerUsage(
        cacheBytes: 0,
        temporaryBytes: 0,
        removableItemCount: 0
    )

    var totalBytes: Int64 {
        let (total, overflow) = cacheBytes.addingReportingOverflow(temporaryBytes)
        return overflow ? Int64.max : max(0, total)
    }
}

struct LimitedCleanerResult: Equatable {
    let before: LimitedCleanerUsage
    let after: LimitedCleanerUsage
    let removedItemCount: Int
    let failedItemCount: Int

    var freedBytes: Int64 {
        max(0, before.totalBytes - after.totalBytes)
    }
}

enum LimitedCleanerError: Error, Equatable {
    case unsafeContainerRoot
}

enum LimitedCleanerService {
    typealias ContainerRootValidator = (URL) -> Bool

    // Evita recursiones excesivas si la caché contiene miles de directorios
    // anidados. Los niveles no inspeccionables se conservan, nunca se fuerzan.
    private static let maximumDirectoryDepth = 64

    private static func safeAdd(_ left: Int64, _ right: Int64) -> Int64 {
        let (value, overflow) = left.addingReportingOverflow(max(0, right))
        return overflow ? Int64.max : value
    }

    /// This explicit allowlist is the product boundary. Do not add global `/var`
    /// paths here: this cleaner is intentionally limited to per-app disposable data.
    static let allowedRelativeDirectories = ["Library/Caches", "tmp"]

    static func scan(
        containerURL: URL,
        rootValidator: ContainerRootValidator
    ) throws -> LimitedCleanerUsage {
        try withValidatedRootDescriptor(containerURL, rootValidator: rootValidator) { rootDescriptor in
            let cache = scanAllowedDirectory(
                components: ["Library", "Caches"],
                rootDescriptor: rootDescriptor
            )
            let temporary = scanAllowedDirectory(
                components: ["tmp"],
                rootDescriptor: rootDescriptor
            )
            return LimitedCleanerUsage(
                cacheBytes: cache.bytes,
                temporaryBytes: temporary.bytes,
                removableItemCount: cache.itemCount + temporary.itemCount
            )
        }
    }

    static func clean(
        containerURL: URL,
        rootValidator: ContainerRootValidator
    ) throws -> LimitedCleanerResult {
        let before = try scan(containerURL: containerURL, rootValidator: rootValidator)
        var removal = RemovalSummary()

        try withValidatedRootDescriptor(containerURL, rootValidator: rootValidator) { rootDescriptor in
            for components in [["Library", "Caches"], ["tmp"]] {
                guard let directoryDescriptor = openDirectory(
                    components: components,
                    relativeTo: rootDescriptor
                ) else {
                    continue
                }
                removeDirectoryContents(directoryDescriptor, summary: &removal)
                close(directoryDescriptor)
            }
        }

        let after = try scan(containerURL: containerURL, rootValidator: rootValidator)
        return LimitedCleanerResult(
            before: before,
            after: after,
            removedItemCount: removal.removedItemCount,
            failedItemCount: removal.failedItemCount
        )
    }

    private static func withValidatedRootDescriptor<T>(
        _ rawURL: URL,
        rootValidator: ContainerRootValidator,
        operation: (Int32) throws -> T
    ) throws -> T {
        guard rawURL.isFileURL else { throw LimitedCleanerError.unsafeContainerRoot }
        let root = rawURL.standardizedFileURL
        guard root.path.hasPrefix("/"),
              root.path != "/",
              rootValidator(root) else {
            throw LimitedCleanerError.unsafeContainerRoot
        }

        let descriptor = open(
            root.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else { throw LimitedCleanerError.unsafeContainerRoot }
        defer { close(descriptor) }
        return try operation(descriptor)
    }

    private static func scanAllowedDirectory(
        components: [String],
        rootDescriptor: Int32
    ) -> ScanSummary {
        guard let directoryDescriptor = openDirectory(
            components: components,
            relativeTo: rootDescriptor
        ) else {
            return .empty
        }
        defer { close(directoryDescriptor) }
        return scanDirectory(directoryDescriptor)
    }

    private static func openDirectory(
        components: [String],
        relativeTo rootDescriptor: Int32
    ) -> Int32? {
        var currentDescriptor = dup(rootDescriptor)
        guard currentDescriptor >= 0 else { return nil }

        for component in components {
            let nextDescriptor = component.withCString {
                openat(
                    currentDescriptor,
                    $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                )
            }
            close(currentDescriptor)
            guard nextDescriptor >= 0 else { return nil }
            currentDescriptor = nextDescriptor
        }
        return currentDescriptor
    }

    private static func scanDirectory(
        _ directoryDescriptor: Int32, depth: Int = 0
    ) -> ScanSummary {
        guard depth < maximumDirectoryDepth else { return .empty }
        var result = ScanSummary.empty
        forEachEntry(in: directoryDescriptor) { name, information in
            switch information.st_mode & S_IFMT {
            case S_IFREG:
                result.bytes = safeAdd(result.bytes, Int64(information.st_size))
                result.itemCount += 1
            case S_IFDIR:
                let childDescriptor = name.withCString {
                    openat(
                        directoryDescriptor,
                        $0,
                        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                    )
                }
                guard childDescriptor >= 0 else { return }
                let nested = scanDirectory(childDescriptor, depth: depth + 1)
                close(childDescriptor)
                result.bytes = safeAdd(result.bytes, nested.bytes)
                result.itemCount += nested.itemCount
            default:
                // Symbolic links, sockets and device nodes are never followed or counted.
                break
            }
        }
        return result
    }

    private static func removeDirectoryContents(
        _ directoryDescriptor: Int32,
        summary: inout RemovalSummary,
        depth: Int = 0
    ) {
        guard depth < maximumDirectoryDepth else {
            summary.failedItemCount += 1
            return
        }
        forEachEntry(in: directoryDescriptor) { name, information in
            switch information.st_mode & S_IFMT {
            case S_IFREG:
                let result = name.withCString { unlinkat(directoryDescriptor, $0, 0) }
                if result == 0 {
                    summary.removedItemCount += 1
                } else if errno != ENOENT {
                    summary.failedItemCount += 1
                }
            case S_IFDIR:
                let childDescriptor = name.withCString {
                    openat(
                        directoryDescriptor,
                        $0,
                        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                    )
                }
                guard childDescriptor >= 0 else {
                    if errno != ENOENT && errno != ELOOP {
                        summary.failedItemCount += 1
                    }
                    return
                }
                removeDirectoryContents(childDescriptor, summary: &summary, depth: depth + 1)
                close(childDescriptor)

                let result = name.withCString {
                    unlinkat(directoryDescriptor, $0, AT_REMOVEDIR)
                }
                if result != 0,
                   errno != ENOENT,
                   errno != ENOTEMPTY {
                    summary.failedItemCount += 1
                }
            default:
                // Preserve and never follow symbolic links or special nodes.
                break
            }
        }
    }

    private static func forEachEntry(
        in directoryDescriptor: Int32,
        body: (String, stat) -> Void
    ) {
        let iterationDescriptor = dup(directoryDescriptor)
        guard iterationDescriptor >= 0,
              let directory = fdopendir(iterationDescriptor) else {
            if iterationDescriptor >= 0 { close(iterationDescriptor) }
            return
        }
        defer { closedir(directory) }

        while let entry = readdir(directory) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) {
                    String(cString: $0)
                }
            }
            guard name != ".", name != ".." else { continue }

            var information = stat()
            let status = name.withCString {
                fstatat(directoryDescriptor, $0, &information, AT_SYMLINK_NOFOLLOW)
            }
            guard status == 0 else { continue }
            body(name, information)
        }
    }
}

private struct ScanSummary {
    var bytes: Int64
    var itemCount: Int

    static let empty = ScanSummary(bytes: 0, itemCount: 0)
}

private struct RemovalSummary {
    var removedItemCount = 0
    var failedItemCount = 0
}
