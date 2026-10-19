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

    /// Construye ANTENA SOLA sin suponer que UnityFS tiene un solo bloque.
    /// Sólo se acepta un nodo del perfil conocido (45.964 bytes), con dos valores
    /// de calibración originales. Los archivos desconocidos se dejan intactos.
    static func build(from original: Data, rejectKnownModified: Bool = true) throws -> Data {
        let parsed = try parse(original, findTarget: true)
        guard let targetOffset = parsed.targetOffset else {
            throw Failure.unsupported("no se encontró un nodo de antena original verificable")
        }
        if rejectKnownModified {
            #if canImport(CryptoKit)
            let originalNode = Data(parsed.plain[targetOffset..<(targetOffset + expectedBytes)])
            let hash = SHA256.hash(data: originalNode).map { String(format: "%02x", $0) }.joined()
            guard !knownModifiedResources.contains(hash) else {
                throw Failure.unsupported("el archivo de origen ya incluye AIMBOT")
            }
            #else
            throw Failure.unsupported("no está disponible el verificador SHA-256")
            #endif
        }
        var updatedPlain = parsed.plain
        for offset in profileOffsets {
            let at = targetOffset + offset
            guard Array(updatedPlain[at..<(at + 4)]) == cleanBits else {
                throw Failure.unsupported("la calibración original de antena no coincide")
            }
            updatedPlain.replaceSubrange(at..<(at + 4), with: antennaBits)
        }

        // Conserva la cantidad de bloques y nodos, las longitudes descomprimidas,
        // sus rutas y los flags adicionales. Sólo cambia la compresión de los
        // bloques afectados de LZ4HC a LZ4, formato equivalente soportado por Unity.
        var info = parsed.blockInfo
        var rebuiltBlocks = [UInt8]()
        var offsetInPlain = 0
        for block in parsed.blocks {
            let next = offsetInPlain + block.unpackedSize
            let slice = Array(updatedPlain[offsetInPlain..<next])
            let originalSlice = Array(parsed.plain[offsetInPlain..<next])
            let packed: [UInt8]
            let mode: UInt16
            if slice == originalSlice {
                packed = Array(parsed.full[block.packedOffset..<(block.packedOffset + block.packedSize)])
                mode = block.flags & 0x3F
            } else {
                packed = compressLZ4(slice)
                mode = 2
            }
            replaceU32(&info, at: block.infoOffset + 4, value: UInt32(packed.count))
            replaceU16(&info, at: block.infoOffset + 8,
                       value: (block.flags & ~UInt16(0x3F)) | mode)
            rebuiltBlocks.append(contentsOf: packed)
            offsetInPlain = next
        }

        // El hash de la información de bloques es un campo de integridad UnityFS.
        // CryptoKit, cuando está disponible (iPhone), permite recalcular MD5.
        #if canImport(CryptoKit)
        let md5 = Insecure.MD5.hash(data: Data(updatedPlain))
        info.replaceSubrange(0..<16, with: md5)
        #endif
        let packedInfo = compressLZ4(info)
        var output: [UInt8]
        if parsed.infoAtEnd {
            output = Array(parsed.full[0..<parsed.dataStart])
            output.append(contentsOf: rebuiltBlocks)
            output.append(contentsOf: parsed.originalDataTail)
            output.append(contentsOf: packedInfo)
        } else {
            output = Array(parsed.full[0..<parsed.infoStart])
            output.append(contentsOf: packedInfo)
            if parsed.dataWasAligned || (parsed.flags & 0x200) != 0 {
                while output.count % 16 != 0 { output.append(0) }
            }
            output.append(contentsOf: rebuiltBlocks)
            output.append(contentsOf: parsed.originalDataTail)
        }
        let bundleEnd = output.count
        output.append(contentsOf: parsed.full[parsed.bundleEnd..<parsed.full.count])
        replaceU64(&output, at: parsed.sizePosition, value: UInt64(bundleEnd))
        replaceU32(&output, at: parsed.sizePosition + 8, value: UInt32(packedInfo.count))
        replaceU32(&output, at: parsed.sizePosition + 12, value: UInt32(info.count))
        replaceU32(&output, at: parsed.sizePosition + 16,
                   value: (parsed.flags & ~UInt32(0x3F)) | 2)

        // Verifica que todo el contenido descomprimido, todos los nodos y la
        // distribución de bloques siguen siendo correctos antes de devolver bytes.
        let checked = try parse(Data(output), findTarget: false)
        guard checked.plain == updatedPlain,
              checked.nodes == parsed.nodes,
              checked.blocks.map(\.unpackedSize) == parsed.blocks.map(\.unpackedSize) else {
            throw Failure.unsupported("falló la verificación de integridad después de reconstruir UnityFS")
        }
        return Data(output)
    }

    #if ANTENNA_TESTING
    static func unpackForTesting(_ resource: Data) throws -> [UInt8] {
        try parse(resource, findTarget: false).plain
    }
    #endif

    private struct StorageBlock {
        let unpackedSize: Int
        let packedSize: Int
        let flags: UInt16
        let infoOffset: Int
        let packedOffset: Int
    }

    private struct Node: Equatable {
        let offset: Int
        let size: Int
        let flags: UInt32
        let path: String
    }

    private struct Bundle {
        let full: [UInt8]
        let bundleEnd: Int
        let sizePosition: Int
        let flags: UInt32
        let dataStart: Int
        let infoStart: Int
        let infoAtEnd: Bool
        let dataWasAligned: Bool
        let originalDataTail: [UInt8]
        let blockInfo: [UInt8]
        let blocks: [StorageBlock]
        let nodes: [Node]
        let plain: [UInt8]
        let targetOffset: Int?
    }

    private static func parse(_ data: Data, findTarget: Bool) throws -> Bundle {
        let bytes = [UInt8](data)
        guard bytes.count >= 80, bytes.count <= maxBundleBytes,
              Array(bytes.prefix(8)) == Array("UnityFS\0".utf8) else {
            throw Failure.unsupported("no es un paquete UnityFS reconocido")
        }
        var pos = 8
        guard try readU32(bytes, &pos) == 8 else {
            throw Failure.unsupported("versión UnityFS distinta de la compatible")
        }
        let engine = try readCString(bytes, &pos)
        let revision = try readCString(bytes, &pos)
        guard engine == "5.x.x", revision == "2018.4.12f1" else {
            throw Failure.unsupported("versión de Unity diferente del perfil analizado")
        }
        let sizePosition = pos
        let bundleSize = try readU64(bytes, &pos)
        let infoCompressed = Int(try readU32(bytes, &pos))
        let infoPlain = Int(try readU32(bytes, &pos))
        let flags = try readU32(bytes, &pos)
        let infoMode = Int(flags & 0x3F)
        let infoAtEnd = (flags & 0x80) != 0
        guard [0, 2, 3].contains(infoMode), infoCompressed > 0,
              infoPlain >= 34, infoPlain <= 1_048_576,
              bundleSize > UInt64(pos), bundleSize <= UInt64(bytes.count) else {
            throw Failure.unsupported("cabecera UnityFS inválida o formato de compresión no admitido")
        }
        let end = Int(bundleSize)
        func aligned(_ n: Int) -> Int { (n + 15) & ~15 }

        // Versiones UnityFS 7+ suelen alinear el comienzo del índice a 16 bytes.
        // 0x200 significa que los datos deben empezar alineados al terminarlo.
        let infoPositions = infoAtEnd ? [end - infoCompressed] : [pos, aligned(pos)]
        var recognizedProfileIssue: String?
        for infoStart in Set(infoPositions).sorted() {
            guard infoStart >= pos, infoCompressed <= end - infoStart,
                  infoStart - pos < 16 || infoAtEnd else { continue }
            if !infoAtEnd && !bytes[pos..<infoStart].allSatisfy({ $0 == 0 }) { continue }
            let packedInfo = Array(bytes[infoStart..<(infoStart + infoCompressed)])
            guard let info = try? decodeBlock(packedInfo, mode: infoMode, expected: infoPlain),
                  info.count >= 34 else { continue }
            var cursor = 16
            guard let blockCountRaw = try? readU32(info, &cursor),
                  blockCountRaw > 0, blockCountRaw <= 4096 else { continue }
            var descriptors = [(size: Int, packed: Int, flags: UInt16, pos: Int)]()
            var totalPlain = 0
            var totalPacked = 0
            var malformed = false
            for _ in 0..<Int(blockCountRaw) {
                let at = cursor
                guard let sizeRaw = try? readU32(info, &cursor),
                      let packedRaw = try? readU32(info, &cursor),
                      let flagsRaw = try? readU16(info, &cursor) else {
                    malformed = true
                    break
                }
                let size = Int(sizeRaw), packedSize = Int(packedRaw)
                guard size > 0, packedSize > 0,
                      size <= maxBundleBytes - totalPlain,
                      packedSize <= maxBundleBytes - totalPacked,
                      [0, 2, 3].contains(Int(flagsRaw & 0x3F)) else {
                    malformed = true
                    break
                }
                totalPlain += size
                totalPacked += packedSize
                descriptors.append((size, packedSize, flagsRaw, at))
            }
            if malformed { continue }
            guard let nodeCountRaw = try? readU32(info, &cursor),
                  nodeCountRaw > 0, nodeCountRaw <= 4096 else { continue }
            var nodes = [Node]()
            for _ in 0..<Int(nodeCountRaw) {
                guard let offsetRaw = try? readU64(info, &cursor),
                      let sizeRaw = try? readU64(info, &cursor),
                      let nodeFlags = try? readU32(info, &cursor),
                      let name = try? readCString(info, &cursor),
                      offsetRaw <= UInt64(totalPlain),
                      sizeRaw <= UInt64(totalPlain) - offsetRaw else {
                    malformed = true
                    break
                }
                nodes.append(Node(offset: Int(offsetRaw), size: Int(sizeRaw),
                                  flags: nodeFlags, path: name))
            }
            if malformed || cursor != info.count { continue }

            let afterInfo = infoAtEnd ? pos : infoStart + infoCompressed
            let dataPositions = [afterInfo, aligned(afterInfo)]
            for dataStart in Set(dataPositions).sorted() {
                let dataLimit = infoAtEnd ? infoStart : end
                guard dataStart >= afterInfo, dataStart <= dataLimit,
                      dataStart - afterInfo < 16,
                      totalPacked <= dataLimit - dataStart,
                      bytes[afterInfo..<dataStart].allSatisfy({ $0 == 0 }) else { continue }
                // Si existe 0x200, el inicio de los bloques tiene que estar alineado.
                // Aceptar archivos de versiones antiguas sin padding pese a la bandera 0x200,
                // si todas las comprobaciones de bloques y nodo son correctas.

                var readAt = dataStart
                var plain = [UInt8]()
                plain.reserveCapacity(totalPlain)
                var blocks = [StorageBlock]()
                for descriptor in descriptors {
                    let compressed = Array(bytes[readAt..<(readAt + descriptor.packed)])
                    guard let decoded = try? decodeBlock(compressed,
                                    mode: Int(descriptor.flags & 0x3F),
                                    expected: descriptor.size) else {
                        malformed = true
                        break
                    }
                    plain.append(contentsOf: decoded)
                    blocks.append(StorageBlock(unpackedSize: descriptor.size,
                                               packedSize: descriptor.packed,
                                               flags: descriptor.flags,
                                               infoOffset: descriptor.pos,
                                               packedOffset: readAt))
                    readAt += descriptor.packed
                }
                if malformed { malformed = false; continue }
                let tail = Array(bytes[readAt..<dataLimit])
                // Se permite sólo padding corto y nulo, no datos ignorados.
                guard tail.count < 16 && tail.allSatisfy({ $0 == 0 }) else { continue }

                var target: Int? = nil
                if findTarget {
                    var matches = [Int]()
                    for node in nodes where node.size == expectedBytes {
                        if profileOffsets.allSatisfy({ offset in
                            let at = node.offset + offset
                            return at + 4 <= plain.count &&
                                   Array(plain[at..<(at + 4)]) == cleanBits
                        }) {
                            matches.append(node.offset)
                        }
                    }
                    if matches.count != 1 {
                        let candidates = nodes.filter { $0.size == expectedBytes }.count
                        recognizedProfileIssue = matches.isEmpty
                            ? "nodos: \(nodes.count), bloques: \(blocks.count), perfiles de tamaño esperado: \(candidates); la calibración no coincide"
                            : "se hallaron varios perfiles de antena y el destino es ambiguo"
                        continue
                    }
                    target = matches[0]
                }
                return Bundle(full: bytes, bundleEnd: end,
                              sizePosition: sizePosition, flags: flags,
                              dataStart: dataStart, infoStart: infoStart,
                              infoAtEnd: infoAtEnd,
                              dataWasAligned: dataStart != afterInfo,
                              originalDataTail: tail,
                              blockInfo: info, blocks: blocks, nodes: nodes,
                              plain: plain, targetOffset: target)
            }
        }
        throw Failure.unsupported(
            "estructura de bloques o nodo del perfil no reconocido " +
            "(flags 0x\(String(flags, radix: 16)), perfil: \(expectedBytes) bytes; " +
            "\(recognizedProfileIssue ?? "no se pudo decodificar la tabla de bloques"))")
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
