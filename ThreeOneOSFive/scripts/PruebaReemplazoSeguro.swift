import Foundation

@main
struct PruebaReemplazoSeguro {
    static func main() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("nexora-replace-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }

        let destination = folder.appendingPathComponent("original.dat")
        let source = folder.appendingPathComponent("replacement.dat")
        try Data("ORIGINAL".utf8).write(to: destination)
        try Data("NUEVO SEGURO".utf8).write(to: source)
        let receipt = try FileReplacementService.replace(target: destination, with: source)
        guard receipt.byteCount == Int64(Data("NUEVO SEGURO".utf8).count),
              try Data(contentsOf: destination) == Data("NUEVO SEGURO".utf8) else {
            fatalError("No verificó correctamente el reemplazo")
        }
        print("Reemplazo ordinario: verificado.")

        // Cero bytes es un archivo válido, pero debe verificarse el tamaño real.
        try Data().write(to: source)
        let zero = try FileReplacementService.replace(target: destination, with: source)
        guard zero.byteCount == 0, try Data(contentsOf: destination).isEmpty else {
            fatalError("Falló la verificación de archivo vacío")
        }
        print("Archivo vacío: reemplazo verificado.")

        do {
            _ = try FileReplacementService.replace(target: destination, with: destination)
            fatalError("Se permitió reemplazar el archivo por sí mismo")
        } catch FileReplacementError.sameFile {
            print("Mismo archivo: bloqueado.")
        }

        let shortcut = folder.appendingPathComponent("source-link.dat")
        try fm.createSymbolicLink(at: shortcut, withDestinationURL: destination)
        do {
            _ = try FileReplacementService.replace(target: destination, with: shortcut)
            fatalError("Se siguió un enlace simbólico")
        } catch FileReplacementError.symbolicLinkUnsupported {
            print("Enlace simbólico: bloqueado.")
        }

        let unknownFolder = folder.appendingPathComponent("folder")
        try fm.createDirectory(at: unknownFolder, withIntermediateDirectories: false)
        do {
            _ = try FileReplacementService.replace(target: destination, with: unknownFolder)
            fatalError("Una carpeta se aceptó como archivo")
        } catch FileReplacementError.sourceIsDirectory {
            print("Carpeta como archivo: bloqueada.")
        }

        // Un reemplazo correcto no debe dejar temporales de staging.
        let leftovers = try fm.contentsOfDirectory(atPath: folder.path).filter {
            $0.hasPrefix(".3105-replacement-")
        }
        guard leftovers.isEmpty else { fatalError("Quedaron archivos de staging sin limpiar") }
        print("Temporales de reemplazo: sin residuos.")
        print("REEMPLAZO: 6/6 comprobaciones correctas")
    }
}
