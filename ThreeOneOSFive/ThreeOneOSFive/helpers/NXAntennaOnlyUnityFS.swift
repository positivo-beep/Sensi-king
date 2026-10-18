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
    private static let maxBundleBytes = 8 * 1024 * 1024

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
        var result = Array(parsed.full[0..<parsed.dataStart])
        result.append(contentsOf: compressedBlock)
        result.append(contentsOf: compressedInfo)
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
        guard try readU32(bytes, &pos) == 8 else { throw Failure.unsupported("versión de UnityFS desconocida") }
        let engine = try readCString(bytes, &pos)
        let revision = try readCString(bytes, &pos)
        guard engine == "5.x.x", revision == "2018.4.12f1" else {
            throw Failure.unsupported("versión de los recursos Unity distinta a la examinada")
        }
        let sizePosition = pos
        let bundleSize = try readU64(bytes, &pos)
        let infoCompressed = Int(try readU32(bytes, &pos))
        let infoPlain = Int(try readU32(bytes, &pos))
        let flags = try readU32(bytes, &pos)
        guard flags & 0x80 != 0, flags & 0x40 != 0,
              flags & 0x3F == 2 || flags & 0x3F == 3,
              infoCompressed > 0, infoPlain > 0, infoPlain < 32768,
              bundleSize < UInt64(bytes.count + 1) else {
            throw Failure.unsupported("cabecera/ubicación de bloques inesperada")
        }
        let dataStart = (pos + 15) & ~15
        let end = Int(bundleSize)
        guard dataStart < end, infoCompressed < end - dataStart else {
            throw Failure.unsupported("tamaño de los bloques incoherente")
        }
        let meta = Array(bytes[(end - infoCompressed)..<end])
        let info = try decodeBlock(meta, mode: Int(flags & 0x3F), expected: infoPlain)
        guard info.count >= 34 else { throw Failure.unsupported("tabla de bloques incompleta") }
        var cursor = 16 // hash de 16 bytes; se conserva intacto
        guard try readU32(info, &cursor) == 1 else {
            throw Failure.unsupported("este perfil solo admite un bloque de datos")
        }
        let originalSize = Int(try readU32(info, &cursor))
        let packedSize = Int(try readU32(info, &cursor))
        let blockFlags = try readU16(info, &cursor)
        guard originalSize == expectedBytes, packedSize > 0,
              packedSize <= end - infoCompressed - dataStart,
              blockFlags & 0x3F == 2 || blockFlags & 0x3F == 3,
              try readU32(info, &cursor) == 1 else {
            throw Failure.unsupported("bloque de datos diferente al perfil analizado")
        }
        // Nodo único: el tamaño apunta exactamente al contenido descomprimido.
        let nodeOffset = try readU64(info, &cursor)
        let nodeSize = try readU64(info, &cursor)
        _ = try readU32(info, &cursor)
        _ = try readCString(info, &cursor)
        guard nodeOffset == 0, nodeSize == UInt64(expectedBytes), cursor == info.count else {
            throw Failure.unsupported("tabla interna de recursos incompatible")
        }
        let compressed = Array(bytes[dataStart..<(dataStart + packedSize)])
        let plain = try decodeBlock(compressed, mode: Int(blockFlags & 0x3F), expected: expectedBytes)
        return Bundle(full: bytes, bundleEnd: end, sizePosition: sizePosition,
                      flags: flags, dataStart: dataStart, blockInfo: info, plain: plain)
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
