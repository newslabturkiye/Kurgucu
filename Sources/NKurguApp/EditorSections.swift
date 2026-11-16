import SwiftUI

enum EditorSection: String, CaseIterable, Identifiable {
    case media = "Medya", audio = "Ses", text = "Metin", stickers = "Çıkartmalar", effects = "Efektler", transitions = "Geçişler", captions = "Altyazılar", filters = "Filtreler", adjustment = "Ayar"
    var id: String { rawValue }
    var available: Bool { true }
    var symbol: String {
        switch self {
        case .media: "play.rectangle.fill"
        case .audio: "music.note"
        case .text: "textformat"
        case .stickers: "face.smiling"
        case .effects: "sparkles"
        case .transitions: "arrow.left.arrow.right"
        case .captions: "captions.bubble"
        case .filters: "camera.filters"
        case .adjustment: "slider.horizontal.3"
        }
    }
}

struct EditorSectionBar: View {
    @Binding var selection: EditorSection
    let activate: () -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EditorSection.allCases) { section in
                    Button { selection = section; activate() } label: {
                        VStack(spacing: 5) {
                            Image(systemName: section.symbol).font(.system(size: 21)).frame(height: 25)
                            Text(section.rawValue).font(.system(size: 11, weight: .medium))
                        }.frame(width: 77, height: 58)
                            .foregroundStyle(selection == section ? Studio.accent : Studio.ink)
                            .background(selection == section ? Studio.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain).disabled(!section.available)
                        .opacity(section.available ? 1 : 0.35)
                        .help(section.available ? section.rawValue : "\(section.rawValue): henüz bu sürümde yok")
                        .accessibilityAddTraits(selection == section ? [.isSelected] : [])
                }
            }.padding(.horizontal, 14).padding(.vertical, 7)
        }.background(Studio.panel)
        Divider()
    }
}

struct SectionTools: View {
    let section: EditorSection
    let model: WorkspaceModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(section.rawValue.uppercased(), systemImage: section.symbol).font(.caption.bold())
            if section == .adjustment {
                Text("Tuval ve kadraj").font(.title3.bold())
                Text("9:16, 16:9 ve diğer oranları seç. Seçili video klibinin kadrajını özellikler panelinden düzenle.").font(.callout).foregroundStyle(.secondary)
                Button("Tuval ayarlarını aç") { model.showCanvas = true }.buttonStyle(StudioButton(prominent: true))
                Button("Özellikleri göster") { model.showInspector = true }.buttonStyle(StudioButton())
                Text("Pozlama, kontrast, doygunluk ve sıcaklık için timeline’dan bir video klibi seç.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text(section == .captions ? "Sözcükleri görünür kıl." : "Hikâyene bir başlık.").font(.title3.bold())
                Text(section == .captions ? "SRT dosyası içe aktar, zamanlamayı ve metin stilini düzenle." : "Başlık ve alt bant ekle; font, renk, kontur ve gölgeyi düzenle.").font(.callout).foregroundStyle(.secondary)
                Button(section == .captions ? "Altyazıları düzenle" : "Metin düzenleyiciyi aç") { model.showTitles = true }.buttonStyle(StudioButton(prominent: true))
                if section == .captions {
                    Button("SRT içe aktar", action: model.importSubtitles).buttonStyle(StudioButton())
                    Button("SRT dışa aktar", action: model.exportSubtitles).disabled((model.sequence.titles ?? []).isEmpty)
                    Text("Otomatik konuşma tanıma henüz yok.").font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Text("\((model.sequence.titles ?? []).count) metin öğesi").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.sequence.titles ?? []) { title in
                            Text(title.text).font(.callout).lineLimit(3).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Studio.raised, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }.padding(16)
    }
}
