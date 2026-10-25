import Foundation

@main
struct CodecSelfTest {
    static func main() {
        let result = CarLifeCodecDiagnostics.run()
        print(result)
        precondition(result.hasPrefix("PASS:"), "Unexpected codec test failure")
        do {
            _ = try CarLifeFrame.decode(Data([0,0,0,1,0,0,0,5,1]))
            fatalError("Malformed frame accepted")
        } catch CarLifeFrame.CodecError.invalidLength {
            print("PASS: malformed packet correctly rejected")
        } catch {
            fatalError("Unexpected codec error: \(error)")
        }
    }
}
