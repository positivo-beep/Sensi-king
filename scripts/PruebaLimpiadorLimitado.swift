import Foundation

@main
struct PruebaLimpiadorLimitado {
    static func main() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("nexora-cleaner-tests-\(UUID().uuidString)", isDirectory: true)
        let container = home.appendingPathComponent("permitted", isDirectory: true)
        let caches = container.appendingPathComponent("Library/Caches", isDirectory: true)
        let tmp = container.appendingPathComponent("tmp", isDirectory: true)
        let documents = container.appendingPathComponent("Documents", isDirectory: true)
        try fm.createDirectory(at: caches, withIntermediateDirectories: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        try fm.createDirectory(at: documents, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home) }
        let validator: LimitedCleanerService.ContainerRootValidator = { url in
            url.standardizedFileURL == container.standardizedFileURL
        }
        let cacheFile = caches.appendingPathComponent("cache.bin")
        let tmpFile = tmp.appendingPathComponent("temp.bin")
        let document = documents.appendingPathComponent("user.dat")
        let external = home.appendingPathComponent("external.dat")
        try Data("CACHE".utf8).write(to: cacheFile)
        try Data("TEMP".utf8).write(to: tmpFile)
        try Data("NO TOCAR".utf8).write(to: document)
        try Data("FUERA".utf8).write(to: external)
        let link = caches.appendingPathComponent("external-link")
        try fm.createSymbolicLink(at: link, withDestinationURL: external)

        let before = try LimitedCleanerService.scan(containerURL: container, rootValidator: validator)
        guard before.totalBytes == 9, before.removableItemCount == 2 else {
            fatalError("El análisis incluyó enlaces o documentos fuera de alcance")
        }
        print("Análisis: solo caché y tmp permitidos.")
        let result = try LimitedCleanerService.clean(containerURL: container, rootValidator: validator)
        guard result.freedBytes == 9, result.removedItemCount == 2,
              result.failedItemCount == 0,
              !fm.fileExists(atPath: cacheFile.path), !fm.fileExists(atPath: tmpFile.path),
              try Data(contentsOf: document) == Data("NO TOCAR".utf8),
              try Data(contentsOf: external) == Data("FUERA".utf8) else {
            fatalError("Limpieza no fue selectiva")
        }
        print("Limpieza: documentos y archivos externos intactos.")
        guard !((try fm.destinationOfSymbolicLink(atPath: link.path)).isEmpty) else {
            fatalError("Se borró el enlace simbólico sin permiso")
        }
        print("Enlace simbólico: no seguido ni borrado.")

        do {
            _ = try LimitedCleanerService.clean(containerURL: home, rootValidator: validator)
            fatalError("Se aceptó un contenedor no permitido")
        } catch LimitedCleanerError.unsafeContainerRoot {
            print("Contenedor ajeno: bloqueado.")
        }

        // Una estructura anormalmente profunda no debe causar recursión sin límite
        // ni provocar que se reporte una limpieza completa.
        var current = tmp
        for i in 0..<70 {
            current = current.appendingPathComponent("deep\(i)", isDirectory: true)
            try fm.createDirectory(at: current, withIntermediateDirectories: false)
        }
        let deepData = current.appendingPathComponent("deep-data.bin")
        try Data("NO BORRAR".utf8).write(to: deepData)
        let depthResult = try LimitedCleanerService.clean(containerURL: container, rootValidator: validator)
        guard depthResult.failedItemCount >= 1,
              try Data(contentsOf: deepData) == Data("NO BORRAR".utf8) else {
            fatalError("La profundidad excesiva no se conservó correctamente")
        }
        print("Profundidad excesiva: contenido conservado y advertencia emitida.")
        print("LIMPIADOR LIMITADO: 5/5 comprobaciones correctas")
    }
}
