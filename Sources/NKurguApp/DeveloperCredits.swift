import AppKit
import SwiftUI

@MainActor enum DeveloperCredits {
    static let names = ["Sarphan Uzunoğlu", "Dijital Medya Araştırmaları Derneği", "newslabturkey"]
    static func showAbout() {
        let credits = NSAttributedString(
            string: "Geliştirici\n\n" + names.joined(separator: "\n") + "\n\nOpenCut Classic — mimari ve davranış referansı (MIT).\n" + (Bundle.module.url(forResource: "OpenCut-LICENSE", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""),
            attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "kurgucu",
            .credits: credits
        ])
    }
}

struct DeveloperCreditLabel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("GELİŞTİRİCİ").font(.system(size: 9, weight: .semibold)).tracking(1)
            ForEach(DeveloperCredits.names, id: \.self) { name in
                Text(name).font(.system(size: 10))
            }
        }.foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
