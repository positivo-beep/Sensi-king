#if canImport(CryptoKit)
import CryptoKit
#endif
import Foundation

/// Prepara ANTENA SOLA a partir de los bytes ACTUALES del archivo de destino.
/// No presupone que un AIMBOT sea un original limpio ni escribe directamente en el juego.
/// La escritura y el respaldo pertenecen exclusivamente a PatchTransaction.
///
/// Soporte deliberadamente limitado al perfil UnityFS documentado por los tres
/// pares AIM/AIM+ANTENA. Si cambia la estructura, no crea ningún parche.
enum NXAntennaOnlyUnityFS {
    enum Failure: Error, LocalizedError {
        case unsupported(String)
        var errorDescription: String? {
            switch self {
            case .unsupported(let reason): return "ANTENA SOLA: \(reason). No se cambió ningún archivo."
            }
        }
    }

    private static let cleanBits: [UInt8] = [0x00, 0x00, 0x80, 0x3F] // 1.0
    private static let antennaBits: [UInt8] = [0x00, 0x00, 0x96, 0x43] // 300.0
    private static let profileOffsets = [25260, 38920] // en datos DESCOMPRIMIDOS
    private static let expectedBytes = 45964
    private static let maxBundleBytes = 64 * 1024 * 1024

    /// Huellas conocidas de paquetes AIM y AIM+ANTENA: nunca sirven como original limpio.
    private static let knownModifiedResources: Set<String> = [
        "d18b07f4791fa1601cc84137d8ef54835d6010c4bd1b53af717122a59a60f5a7",
        "6ab17a7332cb4b29b5353dfe2f688b357c3f22b6f34054ef8a57e93bab25b663",
        "0426b218951acdfb516ce886e1b7cb86d53dc3667971d7ffa1e7cc5334d28bab",
        "2902158397e64a5ef48315ee4c3a4da6d91f32f7f162b4e607d1461d5a65ee04",
        "549f9b8631652f398d45131858afe6aca275c8d21e125206b4e05ec8cc1c5834",
        "effcc3f4ecbc4e15e912557d0bfb5e768b99102adcde82bc617aa02f9acb12a4"
    ]

    /// Se llama solo cuando la opción está inactiva y el destino ya existe.
    /// El argumento de test está separado para comprobar el códec con variantes
    /// AIM conocidas; la app siempre emplea la configuración estricta.
    static func build(from original: Data, rejectKnownModified: Bool = true) throws -> Data {
        let parsed = try parse(original)
        if rejectKnownModified {
            #if canImport(CryptoKit)
            // Las huellas conocidas se calcularon sobre el bloque Unity DESCOMPRIMIDO.
            let hash = SHA256.hash(data: Data(parsed.plain)).map { String(format: "%02x", $0) }.joined()
            guard !knownModifiedResources.contains(hash) else {
                throw Failure.unsupported("el archivo actual ya contiene una modificación conocida de AIMBOT")
            }
            #else
            throw Failure.unsupported("no está disponible el verificador SHA-256")
            #endif
        }
        guard parsed.plain.count == expectedBytes else {
            throw Failure.unsupported("el tamaño interno no coincide con la versión analizada")
        }
        var plain = parsed.plain
        for offset in profileOffsets {
            guard Array(plain[offset..<(offset + 4)]) == cleanBits else {
                throw Failure.unsupported("los valores de antena no están en el estado original esperado")
            }
        }
        for offset in profileOffsets { plain.replaceSubrange(offset..<(offset + 4), with: antennaBits) }

        // Reconstrucción del UnityFS conservando nombre de nodo y bytes adicionales.
        // La compresión LZ4 se vuelve a generar, sin parchear bytes comprimidos a ciegas.
        let compressedBlock = compressLZ4(plain)
        var info = parsed.blockInfo
        replaceU32(&info, at: 24, value: UInt32(compressedBlock.count))
        replaceU16(&info, at: 28, value: 2) // bloque LZ4 estándar
        let compressedInfo = compressLZ4(info)
        // Mantener el modo de ubicación del índice del UnityFS original.
        // Un archivo válido puede guardar el índice al principio o al final y
        // puede incluir o no alineación a 16 bytes. No asumir siempre 0xC3.
        var result: [UInt8]
        if parsed.infoAtEnd {
            result = Array(parsed.full[0..<parsed.dataStart])
            result.append(contentsOf: compressedBlock)
            result.append(contentsOf: compressedInfo)
        } else {
            result = Array(parsed.full[0..<parsed.infoStart])
            result.append(contentsOf: compressedInfo)
            if parsed.dataWasAligned {
                while result.count % 16 != 0 { result.append(0) }
            }
            result.append(contentsOf: compressedBlock)
        }
        let bundleEnd = result.count
        result.append(contentsOf: parsed.full[parsed.bundleEnd..<parsed.full.count])
        replaceU64(&result, at: parsed.sizePosition, value: UInt64(bundleEnd))
        replaceU32(&result, at: parsed.sizePosition + 8, value: UInt32(compressedInfo.count))
        replaceU32(&result, at: parsed.sizePosition + 12, value: UInt32(info.count))
        replaceU32(&result, at: parsed.sizePosition + 16, value: (parsed.flags & ~UInt32(0x3F)) | 2)

        // Comprobación independiente de ida y vuelta antes de devolver el archivo.
        let verified = try parse(Data(result))
        guard verified.plain == plain else {
            throw Failure.unsupported("no fue posible verificar el recurso reconstruido")
        }
        return Data(result)
    }

    #if ANTENNA_TESTING
    static func unpackForTesting(_ resource: Data) throws -> [UInt8] { try parse(resource).plain }
    #endif

    private struct Bundle {
        let full: [UInt8]
        let bundleEnd: Int
        let sizePosition: Int
        let flags: UInt32
        let dataStart: Int
        let infoStart: Int
        let infoAtEnd: Bool
        let dataWasAligned: Bool
        let blockInfo: [UInt8]
        let plain: [UInt8]
    }

    private static func parse(_ data: Data) throws -> Bundle {
        let bytes = [UInt8](data)
        guard bytes.count >= 80, bytes.count < maxBundleBytes,
              Array(bytes.prefix(8)) == Array("UnityFS\0".utf8) else {
            throw Failure.unsupported("el archivo no es un UnityFS compatible")
        }
        var pos = 8
        guard try readU32(bytes, &pos) == 8 else {
            throw Failure.unsupported("versión de UnityFS desconocida")
        }
        let engine = try readCString(bytes, &pos)
        let revision = try readCString(bytes, &pos)
        guard engine == "5.x.x", revision == "2018.4.12f1" else {
            throw Failure.unsupported("versión Unity distinta a la examinada")
        }
        let sizePosition = pos
        let bundleSize = try readU64(bytes, &pos)
        let infoCompressed = Int(try readU32(bytes, &pos))
        let infoPlain = Int(try readU32(bytes, &pos))
        let flags = try readU32(bytes, &pos)
        let mode = Int(flags & 0x3F)
        let infoAtEnd = (flags & 0x80) != 0
        guard mode == 0 || mode == 2 || mode == 3,
              infoCompressed > 0, infoPlain >= 34, infoPlain < 32768,
              bundleSize > UInt64(pos), bundleSize <= UInt64(bytes.count) else {
            throw Failure.unsupported("cabecera UnityFS con tamaño o compresión incompatible")
        }
        let end = Int(bundleSize)
        func aligned(_ v: Int) -> Int { (v + 15) & ~15 }

        // UnityFS admite información de bloques al final (0x80) o al comienzo;
        // la bandera 0x40 de padding no es obligatoria en todos los bundles.
        let metadataPositions = infoAtEnd ? [end - infoCompressed] : [pos, aligned(pos)]
        for infoStart in Set(metadataPositions).sorted() {
            guard infoStart >= pos, infoStart <= end,
                  infoCompressed <= end - infoStart else { continue }
            let packedInfo = Array(bytes[infoStart..<(infoStart + infoCompressed)])
            guard let info = try? decodeBlock(packedInfo, mode: mode, expected: infoPlain),
                  info.count >= 34 else { continue }
            var cursor = 16  // reserva/huella de tabla del bundle
            guard let count = try? readU32(info, &cursor), count == 1,
                  let originalSizeRaw = try? readU32(info, &cursor),
                  let packedSizeRaw = try? readU32(info, &cursor),
                  let blockFlagsRaw = try? readU16(info, &cursor) else { continue }
            let originalSize = Int(originalSizeRaw)
            let packedSize = Int(packedSizeRaw)
            let blockMode = Int(blockFlagsRaw & 0x3F)
            guard originalSize == expectedBytes, packedSize > 0,
                  blockMode == 0 || blockMode == 2 || blockMode == 3,
                  let nodeCount = try? readU32(info, &cursor), nodeCount == 1,
                  let nodeOffset = try? readU64(info, &cursor),
                  let nodeSize = try? readU64(info, &cursor),
                  (try? readU32(info, &cursor)) != nil,
                  (try? readCString(info, &cursor)) != nil,
                  nodeOffset == 0, nodeSize == UInt64(expectedBytes),
                  cursor == info.count else { continue }

            let afterMetadata = infoAtEnd ? pos : infoStart + infoCompressed
            let candidates = Set([afterMetadata, aligned(afterMetadata)]).sorted()
            for dataStart in candidates {
                let dataLimit = infoAtEnd ? infoStart : end
                guard dataStart >= afterMetadata, dataStart <= dataLimit,
                      packedSize <= dataLimit - dataStart else { continue }
                let compressed = Array(bytes[dataStart..<(dataStart + packedSize)])
                guard let plain = try? decodeBlock(compressed, mode: blockMode, expected: expectedBytes),
                      plain.count == expectedBytes else { continue }
                // Para este perfil los bloques y la tabla deben ser contiguos;
                // solo se acepta padding cero de 16 bytes donde corresponde.
                let gap = bytes[afterMetadata..<dataStart]
                guard gap.allSatisfy({ $0 == 0 }), gap.count < 16 else { continue }
                return Bundle(full: bytes, bundleEnd: end, sizePosition: sizePosition,
                              flags: flags, dataStart: dataStart, infoStart: infoStart,
                              infoAtEnd: infoAtEnd, dataWasAligned: dataStart != afterMetadata,
                              blockInfo: info, plain: plain)
            }
        }
        throw Failure.unsupported(
            "tabla o ubicación de bloques UnityFS incompatible " +
            "(flags 0x\(String(flags, radix: 16)), " +
            "tamaño interno esperado: \(expectedBytes) bytes)"
        )
    }

    private static func decodeBlock(_ compressed: [UInt8], mode: Int, expected: Int) throws -> [UInt8] {
        if mode == 0 {
            guard compressed.count == expected else { throw Failure.unsupported("bloque sin comprimir inválido") }
            return compressed
        }
        guard mode == 2 || mode == 3 else { throw Failure.unsupported("compresión no admitida") }
        var result = [UInt8]()
        result.reserveCapacity(expected)
        var cursor = 0
        while cursor < compressed.count {
            let token = Int(compressed[cursor]); cursor += 1
            var literalLength = token >> 4
            if literalLength == 15 {
                while true {
                    guard cursor < compressed.count else { throw Failure.unsupported("LZ4 incompleto") }
                    let extra = Int(compressed[cursor]); cursor += 1
                    literalLength += extra
                    if extra != 255 { break }
                }
            }
            guard literalLength <= expected - result.count,
                  literalLength <= compressed.count - cursor else { throw Failure.unsupported("LZ4 desbordado") }
            result.append(contentsOf: compressed[cursor..<(cursor + literalLength)])
            cursor += literalLength
            if cursor == compressed.count { break }
            guard cursor + 1 < compressed.count else { throw Failure.unsupported("LZ4 sin desplazamiento") }
            let distance = Int(compressed[cursor]) | (Int(compressed[cursor + 1]) << 8)
            cursor += 2
            guard distance > 0 && distance <= result.count else { throw Failure.unsupported("referencia LZ4 inválida") }
            var length = (token & 15) + 4
            if (token & 15) == 15 {
                while true {
                    guard cursor < compressed.count else { throw Failure.unsupported("LZ4 incompleto") }
                    let extra = Int(compressed[cursor]); cursor += 1
                    length += extra
                    if extra != 255 { break }
                }
            }
            guard length <= expected - result.count else { throw Failure.unsupported("longitud LZ4 excesiva") }
            for _ in 0..<length { result.append(result[result.count - distance]) }
        }
        guard result.count == expected else { throw Failure.unsupported("tamaño LZ4 inesperado") }
        return result
    }

    /// Codificación LZ4 raw con búsqueda de coincidencias; evita dependencias externas.
    private static func compressLZ4(_ bytes: [UInt8]) -> [UInt8] {
        var result = [UInt8]()
        result.reserveCapacity(bytes.count / 2)
        var lastPosition: [UInt32: Int] = [:]
        var index = 0
        var literalStart = 0
        let maxMatchStart = max(0, bytes.count - 12)

        func key(at position: Int) -> UInt32 {
            UInt32(bytes[position]) | UInt32(bytes[position + 1]) << 8 |
            UInt32(bytes[position + 2]) << 16 | UInt32(bytes[position + 3]) << 24
        }
        func extra(_ length: Int) {
            var remaining = length
            while remaining >= 255 { result.append(255); remaining -= 255 }
            result.append(UInt8(remaining))
        }
        while index <= maxMatchStart && index + 4 <= bytes.count {
            let signature = key(at: index)
            let candidate = lastPosition.updateValue(index, forKey: signature)
            if let candidate, index > candidate, index - candidate <= 65535 {
                var length = 4
                while index + length < bytes.count - 5 &&
                      bytes[candidate + length] == bytes[index + length] { length += 1 }
                let literalLength = index - literalStart
                let matchLength = length - 4
                result.append(UInt8(min(literalLength, 15) << 4 | min(matchLength, 15)))
                if literalLength >= 15 { extra(literalLength - 15) }
                result.append(contentsOf: bytes[literalStart..<index])
                let distance = index - candidate
                result.append(UInt8(distance & 255))
                result.append(UInt8((distance >> 8) & 255))
                if matchLength >= 15 { extra(matchLength - 15) }
                let next = index + length
                if length > 1 && next <= bytes.count {
                    for position in (index + 1)..<next where position + 4 <= bytes.count {
                        lastPosition[key(at: position)] = position
                    }
                }
                index = next
                literalStart = next
            } else { index += 1 }
        }
        let finalLiteralLength = bytes.count - literalStart
        result.append(UInt8(min(finalLiteralLength, 15) << 4))
        if finalLiteralLength >= 15 { extra(finalLiteralLength - 15) }
        result.append(contentsOf: bytes[literalStart..<bytes.count])
        return result
    }

    private static func readCString(_ a: [UInt8], _ position: inout Int) throws -> String {
        guard position < a.count, let end = a[position...].firstIndex(of: 0),
              end - position <= 256,
              let string = String(bytes: a[position..<end], encoding: .utf8) else {
            throw Failure.unsupported("cadena UnityFS dañada")
        }
        position = end + 1
        return string
    }
    private static func readU16(_ a: [UInt8], _ position: inout Int) throws -> UInt16 {
        guard position + 2 <= a.count else { throw Failure.unsupported("datos truncados") }
        defer { position += 2 }
        return UInt16(a[position]) << 8 | UInt16(a[position + 1])
    }
    private static func readU32(_ a: [UInt8], _ position: inout Int) throws -> UInt32 {
        guard position + 4 <= a.count else { throw Failure.unsupported("datos truncados") }
        defer { position += 4 }
        return UInt32(a[position]) << 24 | UInt32(a[position + 1]) << 16 |
            UInt32(a[position + 2]) << 8 | UInt32(a[position + 3])
    }
    private static func readU64(_ a: [UInt8], _ position: inout Int) throws -> UInt64 {
        UInt64(try readU32(a, &position)) << 32 | UInt64(try readU32(a, &position))
    }
    private static func replaceU16(_ a: inout [UInt8], at i: Int, value: UInt16) {
        a[i] = UInt8((value >> 8) & 255); a[i + 1] = UInt8(value & 255)
    }
    private static func replaceU32(_ a: inout [UInt8], at i: Int, value: UInt32) {
        for n in 0..<4 { a[i + n] = UInt8((value >> UInt32(24 - n * 8)) & 255) }
    }
    private static func replaceU64(_ a: inout [UInt8], at i: Int, value: UInt64) {
        for n in 0..<8 { a[i + n] = UInt8((value >> UInt64(56 - n * 8)) & 255) }
    }
}
