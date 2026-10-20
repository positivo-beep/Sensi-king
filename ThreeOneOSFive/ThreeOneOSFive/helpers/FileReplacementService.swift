import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

#if canImport(UniformTypeIdentifiers)
enum ReplacementPickerPolicy {
    static let allowedContentTypes: [UTType] = [.data]
    static let copiesSelectedDocument = true
    static let presentationDelay: TimeInterval = 0.35

    static func accepts(_ type: UTType) -> Bool {
        type.conforms(to: .data) && !type.conforms(to: .folder)
    }
}

#endif

struct FileReplacementSelection: Equatable {
    let targetURL: URL
    let targetName: String
    let sourceURL: URL
}

struct FileReplacementRequest: Identifiable, Equatable {
    let id: UUID
    let targetURL: URL
    let targetName: String

    init(id: UUID = UUID(), targetURL: URL, targetName: String) {
        self.id = id
        self.targetURL = targetURL
        self.targetName = targetName
    }

    func selection(from urls: [URL]) throws -> FileReplacementSelection {
        guard let sourceURL = urls.first else {
            throw FileReplacementError.sourceMissing
        }
        return FileReplacementSelection(
            targetURL: targetURL,
            targetName: targetName,
            sourceURL: sourceURL
        )
    }
}

enum FileReplacementError: Error, Equatable, LocalizedError {
    case targetMissing
    case sourceMissing
    case targetIsDirectory
    case sourceIsDirectory
    case sameFile
    case symbolicLinkUnsupported
    case sourceTooLarge
    case sourceChangedDuringCopy
    case targetChangedDuringCopy
    case replacementFailed

    var errorDescription: String? {
        switch self {
        case .targetMissing: return "The target file no longer exists."
        case .sourceMissing: return "The selected replacement file is unavailable."
        case .targetIsDirectory: return "Folders cannot be replaced with this action."
        case .sourceIsDirectory: return "Select a file, not a folder."
        case .sameFile: return "A file cannot replace itself."
        case .symbolicLinkUnsupported: return "Symbolic links are not supported."
        case .sourceTooLarge: return "The selected file is too large."
        case .sourceChangedDuringCopy: return "The selected file changed during copying. Try again."
        case .targetChangedDuringCopy: return "The original changed during copying. Nothing was replaced."
        case .replacementFailed: return "The file could not be replaced safely."
        }
    }
}

struct FileReplacementResult: Equatable {
    let targetURL: URL
    let byteCount: Int64
}

/// Sustitución transaccional para archivos ordinarios a los que la propia aplicación
/// tiene acceso. No concede acceso a contenedores privados de otras aplicaciones.
enum FileReplacementService {
    private static let chunkSize = 1_024 * 1_024

    /// Los cambios concurrentes se inyectan exclusivamente en las pruebas.
    #if REPLACEMENT_TESTING
    static var testAfterCopy: (() throws -> Void)?
    #endif

    /// lstat/fstat evitan la caché de URLResourceValues, que puede conservar
    /// tamaño o fechas antiguos inmediatamente después de una escritura.
    /// Se comprueban además identidad del archivo e instante de cambio (ctime).
    private struct FileSnapshot: Equatable {
        let device: UInt64
        let inode: UInt64
        let kind: UInt32
        let size: Int64
        let modifiedSeconds: Int64
        let modifiedNanoseconds: Int64
        let changedSeconds: Int64
        let changedNanoseconds: Int64

        init(_ info: stat) {
            device = UInt64(info.st_dev)
            inode = UInt64(info.st_ino)
            kind = UInt32(info.st_mode) & UInt32(S_IFMT)
            size = Int64(info.st_size)
            #if canImport(Darwin)
            modifiedSeconds = Int64(info.st_mtimespec.tv_sec)
            modifiedNanoseconds = Int64(info.st_mtimespec.tv_nsec)
            changedSeconds = Int64(info.st_ctimespec.tv_sec)
            changedNanoseconds = Int64(info.st_ctimespec.tv_nsec)
            #else
            modifiedSeconds = Int64(info.st_mtim.tv_sec)
            modifiedNanoseconds = Int64(info.st_mtim.tv_nsec)
            changedSeconds = Int64(info.st_ctim.tv_sec)
            changedNanoseconds = Int64(info.st_ctim.tv_nsec)
            #endif
        }

        var isRegular: Bool { kind == UInt32(S_IFREG) }
        var isDirectory: Bool { kind == UInt32(S_IFDIR) }
        var isSymbolicLink: Bool { kind == UInt32(S_IFLNK) }
    }

    private static func snapshot(at url: URL, missing: FileReplacementError) throws -> FileSnapshot {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw missing }
        return FileSnapshot(info)
    }

    private static func snapshot(fd: Int32) throws -> FileSnapshot {
        var info = stat()
        guard fstat(fd, &info) == 0 else { throw FileReplacementError.replacementFailed }
        return FileSnapshot(info)
    }

    static func replace(
        target targetURL: URL,
        with sourceURL: URL,
        fileManager: FileManager = .default
    ) throws -> FileReplacementResult {
        let targetBefore = try snapshot(at: targetURL, missing: .targetMissing)
        let sourceBefore = try snapshot(at: sourceURL, missing: .sourceMissing)
        guard !targetBefore.isSymbolicLink, !sourceBefore.isSymbolicLink else {
            throw FileReplacementError.symbolicLinkUnsupported
        }
        guard !targetBefore.isDirectory else { throw FileReplacementError.targetIsDirectory }
        guard !sourceBefore.isDirectory else { throw FileReplacementError.sourceIsDirectory }
        guard targetBefore.isRegular, sourceBefore.isRegular else {
            throw FileReplacementError.replacementFailed
        }
        // Incluye alias mediante enlaces duros, no solo rutas iguales.
        guard !(targetBefore.device == sourceBefore.device &&
                targetBefore.inode == sourceBefore.inode) else {
            throw FileReplacementError.sameFile
        }

        let targetAttributes = try fileManager.attributesOfItem(atPath: targetURL.path)
        let stagingURL = targetURL.deletingLastPathComponent()
            .appendingPathComponent(".3105-replacement-\(UUID().uuidString)")
        guard fileManager.createFile(
            atPath: stagingURL.path,
            contents: nil,
            attributes: retainedAttributes(from: targetAttributes)
        ) else { throw FileReplacementError.replacementFailed }
        // Ante cualquier error el original sigue intacto y no queda staging.
        defer { try? fileManager.removeItem(at: stagingURL) }

        var copied: Int64 = 0
        do {
            // O_NOFOLLOW impide que un enlace simbólico agregado durante la apertura
            // redirija la lectura fuera del archivo que eligió el usuario.
            let sourceFD = open(sourceURL.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
            guard sourceFD >= 0 else { throw FileReplacementError.sourceMissing }
            let source = FileHandle(fileDescriptor: sourceFD, closeOnDealloc: true)
            defer { try? source.close() }
            guard try snapshot(fd: sourceFD) == sourceBefore else {
                throw FileReplacementError.sourceChangedDuringCopy
            }

            let staging = try FileHandle(forWritingTo: stagingURL)
            defer { try? staging.close() }
            while let chunk = try source.read(upToCount: chunkSize), !chunk.isEmpty {
                let (next, overflow) = copied.addingReportingOverflow(Int64(chunk.count))
                guard !overflow else { throw FileReplacementError.sourceTooLarge }
                copied = next
                try staging.write(contentsOf: chunk)
            }
            try staging.synchronize()

            // El descriptor verifica el archivo realmente leído, y lstat comprueba
            // que su nombre todavía se refiere al mismo archivo sin modificaciones.
            guard try snapshot(fd: sourceFD) == sourceBefore,
                  try snapshot(at: sourceURL, missing: .sourceMissing) == sourceBefore,
                  copied == sourceBefore.size else {
                throw FileReplacementError.sourceChangedDuringCopy
            }
        } catch let error as FileReplacementError {
            throw error
        } catch {
            throw FileReplacementError.replacementFailed
        }

        #if REPLACEMENT_TESTING
        try testAfterCopy?()
        #endif

        let staged = try snapshot(at: stagingURL, missing: .replacementFailed)
        guard staged.isRegular, staged.size == copied else {
            throw FileReplacementError.replacementFailed
        }
        // Repetir la comprobación tras cerrar los descriptores: otra aplicación
        // podría haber actualizado el archivo mientras se preparaba el cambio.
        guard try snapshot(at: sourceURL, missing: .sourceMissing) == sourceBefore else {
            throw FileReplacementError.sourceChangedDuringCopy
        }
        guard try snapshot(at: targetURL, missing: .targetMissing) == targetBefore else {
            throw FileReplacementError.targetChangedDuringCopy
        }
        // Mismo directorio: rename es un cambio atómico de nombre en el volumen.
        guard rename(stagingURL.path, targetURL.path) == 0 else {
            throw FileReplacementError.replacementFailed
        }
        return FileReplacementResult(targetURL: targetURL, byteCount: copied)
    }

    private static func retainedAttributes(
        from attributes: [FileAttributeKey: Any]
    ) -> [FileAttributeKey: Any] {
        var result: [FileAttributeKey: Any] = [:]
        if let permissions = attributes[.posixPermissions] {
            result[.posixPermissions] = permissions
        }
        if let protection = attributes[.protectionKey] {
            result[.protectionKey] = protection
        }
        return result
    }
}
