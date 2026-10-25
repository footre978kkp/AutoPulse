import SwiftUI
import ExternalAccessory
import UIKit

enum DiagnosticPackage: String, CaseIterable, Identifiable {
    case control = "حزمة التحكم والاتصال"
    case video = "حزمة الفيديو التجريبية"
    case logs = "حزمة التشخيص والسجلات"
    var id: String { rawValue }
    var detail: String {
        switch self {
        case .control: return "اختبار تغليف وفك بيانات التحكم محليا"
        case .video: return "اختبار اطارات الفيديو محليا بدون بث"
        case .logs: return "تجميع معلومات الاتصال وتقرير الفحص"
        }
    }
}

@main
struct CN7BridgeLabApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
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
    @Published private(set) var packageResults: [String: String] = [:]
    @Published private(set) var accessories: [AccessoryRow] = []
    @Published private(set) var lastScan = "بعد ما انعمل الفحص"
    @Published private(set) var codecResult = "بعد ما انعمل الاختبار"

    init() { EAAccessoryManager.shared().registerForLocalNotifications() }

    func refresh() {
        accessories = EAAccessoryManager.shared().connectedAccessories.map { item in
            AccessoryRow(id: item.connectionID, name: item.name,
                         maker: item.manufacturer, model: item.modelNumber,
                         protocols: item.protocolStrings)
        }
        lastScan = Date().formatted(date: .abbreviated, time: .standard)
    }

    func runLocalTest() { codecResult = CarLifeCodecDiagnostics.run() }

    func testPackage(_ package: DiagnosticPackage) {
        switch package {
        case .control, .video:
            packageResults[package.id] = CarLifeCodecDiagnostics.run().hasPrefix("PASS")
                ? "نجح الاختبار المحلي" : "فشل الاختبار المحلي"
        case .logs:
            refresh()
            packageResults[package.id] = "تم تحديث بيانات الفحص"
        }
    }

    func exportReport() {
        var lines = [
            "CN7 Bridge Lab - Diagnostic report",
            "Phone: \(UIDevice.current.model); iOS \(UIDevice.current.systemVersion)",
            "Scan time: \(lastScan)",
            "Visible EA accessories: \(accessories.count)",
            "Local frame codec: \(codecResult)"
        ]
        for item in DiagnosticPackage.allCases {
            lines.append("\(item.rawValue): \(packageResults[item.id] ?? "لم يختبر")")
        }
        for item in accessories {
            lines.append("Accessory: \(item.name) | \(item.maker) | \(item.model)")
            lines.append("Protocols: \(item.protocols.joined(separator: ", "))")
        }
        lines.append("No accessory listed does not prove CarLife is absent.")
        lines.append("This app cannot open Apple CarPlay or an unauthorized USB transport.")
        UIPasteboard.general.string = lines.joined(separator: "\n")
    }
}

struct ContentView: View {
    @StateObject private var diagnostic = AccessoryDiagnostics()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("CN7 Bridge Lab").font(.largeTitle.bold())
                        Text("مختبر فحص اتصال شاشة النترا CN7c")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    GroupBox("حالة اتصال USB") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("تاريخ الفحص: \(diagnostic.lastScan)")
                            Text("الملحقات الظاهرة: \(diagnostic.accessories.count)").font(.headline)
                            if diagnostic.accessories.isEmpty {
                                Text("ما ظهرت ملحقات عبر واجهة External Accessory. هذا لا يعني ان CarLife مفصول.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(diagnostic.accessories) { accessory in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(accessory.name).font(.headline)
                                        Text("الشركة: \(accessory.maker) | الموديل: \(accessory.model)")
                                        Text("البروتوكولات: \(accessory.protocols.joined(separator: ", "))")
                                            .font(.caption).textSelection(.enabled)
                                    }
                                    Divider()
                                }
                            }
                            Button("فحص الاتصال مرة ثانية") { diagnostic.refresh() }
                                .buttonStyle(.borderedProminent)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("اختبار بروتوكول CarLife") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("اختبار محلي فقط. لا يرسل بيانات للسيارة ولا يشغل CarPlay.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(diagnostic.codecResult)
                                .font(.footnote.monospaced()).textSelection(.enabled)
                            Button("اختبار كود CarLife") { diagnostic.runLocalTest() }
                                .buttonStyle(.bordered)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("الحزم الثلاث التجريبية") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(DiagnosticPackage.allCases) { package in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(package.rawValue).font(.headline)
                                    Text(package.detail).font(.subheadline).foregroundStyle(.secondary)
                                    Text(diagnostic.packageResults[package.id] ?? "لم يختبر").font(.caption)
                                    Button("اختبار الحزمة") { diagnostic.testPackage(package) }
                                        .buttonStyle(.bordered)
                                }
                                Divider()
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("تقرير التشخيص") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("والسيارة واقفة، وصل الايفون وافتح CarLife، بعدها افحص الاتصال.")
                            Button("نسخ تقرير التشخيص") { diagnostic.exportReport() }
                                .buttonStyle(.borderedProminent)
                            Text("النسخة الحالية مختبر تشخيص، مو CarPlay حقيقي.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding()
            }
            .navigationTitle("مختبر ربط النترا")
            .environment(\.layoutDirection, .rightToLeft)
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