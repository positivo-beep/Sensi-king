import Foundation

/// Comprobaciones preventivas antes de activar recursos incorporados.
/// No concede permisos de iOS y no escribe en el archivo original.
enum NXActivationPreflight {
    enum Failure: LocalizedError {
        case missingOriginal
        case inaccessibleOriginal
        case invalidOriginal
        case unreadableOriginal
        case readOnlyOriginal
        case invalidResource

        var errorDescription: String? {
            switch self {
            case .missingOriginal:
                return "No se encontró el archivo original en su ruta actual. No se aplicó ningún cambio."
            case .inaccessibleOriginal:
                return "iOS no permite acceder al archivo de destino. No se aplicó ningún cambio; verifica los permisos autorizados."
            case .invalidOriginal:
                return "El archivo de destino no es un archivo regular UnityFS válido. Se canceló para proteger los datos."
            case .unreadableOriginal:
                return "No se puede leer el original para crear un respaldo verificado. No se aplicó ningún cambio."
            case .readOnlyOriginal:
                return "El destino no tiene permiso de escritura. No se intentó reemplazarlo."
            case .invalidResource:
                return "El recurso incluido en la IPA no pasó la comprobación de cabecera y tamaño UnityFS. No se aplicó ningún cambio."
            }
        }
    }

    private static let magic = Array("UnityFS\0".utf8)
    private static let maximumResourceSize = 16 * 1024 * 1024
    private static let maximumOriginalSize = 128 * 1024 * 1024

    /// Verifica solo el envoltorio básico: no certifica que Unity pueda cargar
    /// cada objeto interno ni que una variante funcione con otra versión.
    static func validateBundledResource(_ data: Data) throws {
        guard data.count >= 64, data.count <= maximumResourceSize,
              Array(data.prefix(magic.count)) == magic else { throw Failure.invalidResource }
        let bytes = Array(data)
        func unsignedBE(_ start: Int, _ length: Int) -> UInt64 {
            bytes[start..<(start + length)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }
        let format = unsignedBE(8, 4)
        guard format >= 6, format <= 8 else { throw Failure.invalidResource }
        var index = 12
        for _ in 0..<2 {
            guard let end = bytes[index...].firstIndex(of: 0), end - index <= 128 else {
                throw Failure.invalidResource
            }
            index = end + 1
            guard index + 20 <= bytes.count else { throw Failure.invalidResource }
        }
        let totalDeclared = unsignedBE(index, 8)
        let compressedInfo = unsignedBE(index + 8, 4)
        let decompressedInfo = unsignedBE(index + 12, 4)
        guard totalDeclared >= UInt64(index + 20),
              totalDeclared <= UInt64(data.count),
              compressedInfo > 0, decompressedInfo > 0,
              compressedInfo <= UInt64(data.count - index - 20),
              decompressedInfo <= UInt64(maximumResourceSize) else {
            throw Failure.invalidResource
        }
    }

    /// Falla antes de modificar cualquier archivo cuando el original no está
    /// disponible. Las condiciones también se comprueban durante la transacción
    /// para detectar cambios entre esta revisión y la escritura.
    static func validateReadableWritableOriginal(
        at url: URL, fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: url.path) else { throw Failure.missingOriginal }
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
            ])
        } catch {
            throw Failure.inaccessibleOriginal
        }
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size >= 64,
              size <= maximumOriginalSize else { throw Failure.invalidOriginal }
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw Failure.unreadableOriginal
        }
        // Esta comprobación es preventiva y no otorga permisos. La transacción
        // puede fallar igualmente si iOS revoca el acceso posteriormente.
        guard fileManager.isWritableFile(atPath: url.path) else {
            throw Failure.readOnlyOriginal
        }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            guard Array(handle.readData(ofLength: magic.count)) == magic else {
                throw Failure.invalidOriginal
            }
        } catch let error as Failure {
            throw error
        } catch {
            throw Failure.unreadableOriginal
        }
    }
}
