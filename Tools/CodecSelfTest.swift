import Foundation

@main
struct CodecSelfTest {
    static func main() {
        let report = CarLifeCodecDiagnostics.run()
        print(report)
        if !report.hasPrefix("PASS") { exit(1) }
        do {
            _ = try CarLifeFrame.decode(Data([0, 0, 0]))
            print("FAIL: should reject undersized frames")
            exit(1)
        } catch {
            print("PASS: malformed packet correctly rejected")
        }
    }
}