import Foundation

struct CarLifeFrame: Equatable {
    let channel: UInt32
    let payload: Data

    enum CodecError: Error, CustomStringConvertible {
        case unsupportedChannel(UInt32)
        case frameTooShort
        case oversizedPayload(Int)
        case invalidLength(expected: Int, actual: Int)
        var description: String {
            switch self {
            case .unsupportedChannel(let c): return "Invalid channel: \(c)"
            case .frameTooShort: return "The CarLife frame is shorter than 8 bytes"
            case .oversizedPayload(let n): return "Payload too large: \(n)"
            case .invalidLength(let expected, let actual):
                return "Expected \(expected) bytes, received \(actual)"
            }
        }
    }

    static func decode(_ raw: Data) throws -> CarLifeFrame {
        let bytes = [UInt8](raw)
        guard bytes.count >= 8 else { throw CodecError.frameTooShort }
        let channel = u32BE(bytes, at: 0)
        guard (1...6).contains(channel) else { throw CodecError.unsupportedChannel(channel) }
        let payloadLength = Int(u32BE(bytes, at: 4))
        guard payloadLength <= 64 * 1024 * 1024 else {
            throw CodecError.oversizedPayload(payloadLength)
        }
        guard bytes.count - 8 == payloadLength else {
            throw CodecError.invalidLength(expected: payloadLength, actual: bytes.count - 8)
        }
        return CarLifeFrame(channel: channel, payload: raw.subdata(in: 8..<raw.count))
    }

    func encode() throws -> Data {
        guard (1...6).contains(channel) else { throw CodecError.unsupportedChannel(channel) }
        guard payload.count <= 64 * 1024 * 1024 else {
            throw CodecError.oversizedPayload(payload.count)
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(8 + payload.count)
        bytes.append(contentsOf: Self.be32(channel))
        bytes.append(contentsOf: Self.be32(UInt32(payload.count)))
        bytes.append(contentsOf: payload)
        return Data(bytes)
    }

    var commandType: UInt32? {
        guard channel == 1 || channel == 6 else { return nil }
        let bytes = [UInt8](payload)
        guard bytes.count >= 8 else { return nil }
        return Self.u32BE(bytes, at: 4)
    }

    private static func u32BE(_ data: [UInt8], at i: Int) -> UInt32 {
        (UInt32(data[i]) << 24) | (UInt32(data[i+1]) << 16) |
            (UInt32(data[i+2]) << 8) | UInt32(data[i+3])
    }

    private static func be32(_ value: UInt32) -> [UInt8] {
        [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
         UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
    }
}

struct CarLifeCodecDiagnostics {
    static func run() -> String {
        let sample = Data([0,0,0,1, 0,0,0,8, 0,0,0,0, 0,1,128,1])
        do {
            let decoded = try CarLifeFrame.decode(sample)
            let roundTrip = try decoded.encode()
            guard decoded.channel == 1,
                  decoded.commandType == 0x00018001,
                  roundTrip == sample else { return "FAIL: command round-trip mismatch" }
            let emptyVideo = CarLifeFrame(channel: 2, payload: Data())
            let videoRoundTrip = try CarLifeFrame.decode(emptyVideo.encode())
            guard videoRoundTrip == emptyVideo else {
                return "FAIL: VIDEO channel round-trip mismatch"
            }
            return "PASS: CMD channel, HU_PROTOCOL_VERSION, VIDEO envelope, encode/decode"
        } catch {
            return "FAIL: \(error)"
        }
    }
}
