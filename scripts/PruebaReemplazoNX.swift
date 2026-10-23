import Foundation

@main
struct NXReplacementSmokeTest {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "nexora-replacement-test-\(UUID().uuidString)", isDirectory: true
        )
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let original = root.appendingPathComponent("original.dat")
        let replacement = root.appendingPathComponent("nuevo.dat")
        let oldBytes = Data("antes".utf8)
        let newBytes = Data("despues".utf8)
        try oldBytes.write(to: original)
        try newBytes.write(to: replacement)
        let result = try FileReplacementService.replace(target: original, with: replacement)
        guard result.byteCount == Int64(newBytes.count),
              try Data(contentsOf: original) == newBytes else {
            fatalError("El reemplazo no conservó los bytes seleccionados")
        }
        print("OK: reemplazo propio y tamaño verificados")

        // No modificar nunca un archivo si origen y destino son el mismo.
        do {
            _ = try FileReplacementService.replace(target: original, with: original)
            fatalError("Se permitió reemplazar el archivo por sí mismo")
        } catch FileReplacementError.sameFile { }
        guard try Data(contentsOf: original) == newBytes else {
            fatalError("El rechazo alteró el archivo")
        }
        print("OK: origen y destino iguales rechazados")

        // No seguir enlaces simbólicos por fuera del directorio de prueba.
        let link = root.appendingPathComponent("acceso-directo.dat")
        try fm.createSymbolicLink(at: link, withDestinationURL: original)
        do {
            _ = try FileReplacementService.replace(target: link, with: replacement)
            fatalError("Se permitió reemplazar un enlace simbólico")
        } catch FileReplacementError.symbolicLinkUnsupported { }
        guard try Data(contentsOf: original) == newBytes else {
            fatalError("El enlace simbólico alteró el original")
        }
        print("OK: symlink rechazado sin alterar destino")

        // Los directorios no deben sustituirse por un archivo.
        let directory = root.appendingPathComponent("carpeta")
        try fm.createDirectory(at: directory, withIntermediateDirectories: false)
        do {
            _ = try FileReplacementService.replace(target: directory, with: replacement)
            fatalError("Se permitió reemplazar un directorio")
        } catch FileReplacementError.targetIsDirectory { }
        print("OK: directorio rechazado")

        // Un archivo vacío es válido; el destino debe terminar con cero bytes.
        let empty = root.appendingPathComponent("vacio.dat")
        try Data().write(to: empty)
        let zero = try FileReplacementService.replace(target: original, with: empty)
        guard zero.byteCount == 0, try Data(contentsOf: original).isEmpty else {
            fatalError("Fallo con contenido vacío")
        }
        print("OK: archivo vacío reemplazado y verificado")

        let stagingLeftovers = try fm.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasPrefix(".3105-replacement-") }
        guard stagingLeftovers.isEmpty else {
            fatalError("Se encontraron archivos intermedios sin eliminar")
        }
        print("OK: ninguna copia temporal quedó abandonada")
    }
}
