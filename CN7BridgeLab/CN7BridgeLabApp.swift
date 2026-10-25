import SwiftUI
import ExternalAccessory
import UIKit

@main
struct CN7BridgeLabApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

@MainActor
final class AccessoryDiagnostics: ObservableObject {
    struct AccessoryRow: Identifiable {
        let id: Int
        let name: String
        let maker: String
        let model: String
        let protocols: [String]
    }

    @Published private(set) var accessories: [AccessoryRow] = []
    @Published private(set) var lastScan = "بعد ما انعمل الفحص"
    @Published private(set) var codecResult = "بعد ما انعمل الاختبار"

    init() {
        EAAccessoryManager.shared().registerForLocalNotifications()
    }

    func refresh() {
        accessories = EAAccessoryManager.shared().connectedAccessories.map { item in
            AccessoryRow(id: item.connectionID,
                         name: item.name,
                         maker: item.manufacturer,
                         model: item.modelNumber,
                         protocols: item.protocolStrings)
        }
        lastScan = Date().formatted(date: .abbreviated, time: .standard)
    }

    func runLocalTest() {
        codecResult = CarLifeCodecDiagnostics.run()
    }

    func exportReport() {
        var lines = [
            "CN7 Bridge Lab — Diagnostic report",
            "Phone: \(UIDevice.current.model); iOS \(UIDevice.current.systemVersion)",
            "Scan time: \(lastScan)",
            "Visible EA accessories: \(accessories.count)",
            "Local frame codec: \(codecResult)"
        ]
        for item in accessories {
            lines.append("Accessory: \(item.name) | \(item.maker) | \(item.model)")
            lines.append("Protocols: \(item.protocols.joined(separator: ", "))")
        }
        lines.append("NOTE: No accessory listed does not prove CarLife is absent. This app cannot open Apple CarPlay or an unauthorized USB transport.")
        UIPasteboard.general.string = lines.joined(separator: "\n")
    }
}

struct ContentView: View {
    @StateObject private var diagnostic = AccessoryDiagnostics()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CN7 Bridge Lab")
                            .font(.largeTitle.bold())
                        Text("اختبار امكانية الوصول الى شاشة النترا CN7c من تطبيق iOS")
                            .foregroundStyle(.secondary)
                    }

                    GroupBox("حالة اتصال USB") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("تاريخ الفحص: \(diagnostic.lastScan)")
                            Text("الملحقات التي يسمح iOS بعرضها: \(diagnostic.accessories.count)")
                                .font(.headline)
                            if diagnostic.accessories.isEmpty {
                                Text("ما ظهرت ملحقات عبر External Accessory. هذا لا يعني ان CarLife مفصول، لان الاتصال قد يكون محجوز لتطبيق Baidu او خارج واجهة Apple العامة.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(diagnostic.accessories) { accessory in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(accessory.name).font(.headline)
                                        Text("الشركة: \(accessory.maker) — الموديل: \(accessory.model)")
                                        Text("البروتوكولات: \(accessory.protocols.isEmpty ? "غير معلنة" : accessory.protocols.joined(separator: ", "))")
                                            .font(.caption)
                                            .textSelection(.enabled)
                                    }
                                    Divider()
                                }
                            }
                            Button("فحص الاتصال مرة ثانية") { diagnostic.refresh() }
                                .buttonStyle(.borderedProminent)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("CarLife protocol — اختبار محلي") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("يفحص تشفير وفك اطارات CarLife من مثال محلي فقط. ما يتصل بالسيارة وما يشغل CarPlay.")
                                .foregroundStyle(.secondary)
                            Text(diagnostic.codecResult).font(.footnote.monospaced())
                                .textSelection(.enabled)
                            Button("اختبار كود بروتوكول CarLife") { diagnostic.runLocalTest() }
                                .buttonStyle(.bordered)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("التقرير") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("والسيارة واقفة، وصل الايفون مباشرة وافتح CarLife بالشاشة، بعدها دوس فحص وانسخ التقرير.")
                            Button("نسخ تقرير التشخيص") { diagnostic.exportReport() }
                                .buttonStyle(.borderedProminent)
                            Text("هذا نموذج تشخيصي، مو نسخة CarPlay شغالة. يحتاج نقل مرخص للبروتوكول وواجهة رسمية لوصول CarPlay حتى يصير تطبيق ربط كامل.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("فحص النترا")
            .onAppear { diagnostic.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: .EAAccessoryDidConnect)) { _ in
                diagnostic.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .EAAccessoryDidDisconnect)) { _ in
                diagnostic.refresh()
            }
        }
    }
}
