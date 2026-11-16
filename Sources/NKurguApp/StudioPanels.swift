import SwiftUI
import KurguCore
import KurguPersistence
import KurguEditing

struct StudioHome: View {
    let model: WorkspaceModel
    @State private var selected: CanvasPreset = .landscape
    @State private var projectName = "Yeni hikâye"
    private let presets: [CanvasPreset] = [.landscape, .portrait, .square, .social]

    private func artwork(_ preset: CanvasPreset) -> String {
        switch preset {
        case .landscape: "Scene-Landscape"
        case .portrait: "Scene-Portrait"
        case .square: "Scene-Square"
        default: "Scene-Social"
        }
    }
    private func subtitle(_ preset: CanvasPreset) -> String {
        switch preset {
        case .landscape: "YouTube, röportaj ve uzun hikâyeler."
        case .portrait: "Telefon ekranını dolduran dikey videolar."
        case .square: "Akışta öne çıkan kare kompozisyonlar."
        default: "Sosyal medya için daha geniş dikey alan."
        }
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                StudioLogo(size: 220).frame(maxWidth: .infinity)
                Text("kurgucu").font(.system(size: 46, weight: .regular, design: .serif)).tracking(-1.5)
                Text("Bir fikirden, son kareye.").font(.system(size: 17, design: .serif))
                Text("Görüntünü düzenle. Sesini bul.\nHer ekrana kendi hikâyeni taşı.")
                    .font(.callout).foregroundStyle(.secondary).lineSpacing(4)
                Button(action: model.openProject) {
                    HStack { Image(systemName: "folder"); Text("Proje aç…"); Spacer(); Text("⌘O").foregroundStyle(.secondary) }
                }.buttonStyle(StudioButton()).padding(.top, 10)
                Button("Çalışma alanına geç") { model.showHome = false }.buttonStyle(StudioButton())
                Spacer(minLength: 12)
                DeveloperCreditLabel()
                Label(model.recoveryStatus, systemImage: "clock.arrow.circlepath").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(width: 280).frame(maxHeight: .infinity).background(Studio.raised)
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Yeni bir hikâye.").font(.system(size: 32, weight: .semibold))
                            Text("Formatını seç. Hikâyene bir ad ver. Kurguya başla.").foregroundStyle(.secondary)
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(presets) { preset in
                                Button { selected = preset } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        ZStack(alignment: .topTrailing) {
                                            GeometryReader { bounds in
                                                StudioArtwork(name: artwork(preset))
                                                    .frame(width: bounds.size.height * 2.1, height: bounds.size.height * 2.1)
                                                    .frame(width: bounds.size.width, height: bounds.size.height).clipped()
                                            }.frame(height: 116)
                                                .background(Color(red: 0.969, green: 0.969, blue: 0.949))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            if selected == preset {
                                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Studio.onAccent, Studio.accent).font(.system(size: 20)).padding(8)
                                            }
                                        }
                                        HStack { Text(preset.label).font(.headline); Spacer(); Text(preset.ratio).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(Studio.accent) }
                                        Text(subtitle(preset)).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(height: 30, alignment: .top)
                                        Text("\(preset.width) × \(preset.height)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Studio.panel, in: RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected == preset ? Studio.accent : Studio.border, lineWidth: selected == preset ? 2 : 1))
                                }.buttonStyle(.plain).accessibilityLabel("\(preset.label), \(preset.ratio)")
                                    .accessibilityAddTraits(selected == preset ? [.isSelected] : [])
                            }
                        }
                        HStack(spacing: 12) {
                            StudioIcon(glyph: .inspector, size: 34)
                            VStack(alignment: .leading, spacing: 3) { Text("Hikâyen güvende.").font(.subheadline.bold()); Text("Otomatik kurtarma kayıtlarına dön.").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Button("Kayıtları gör") { Task { model.recoveryEntries = await model.recovery.entries(); model.showRecovery = true } }.buttonStyle(StudioButton())
                        }.padding(14).background(Studio.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }.padding(28)
                }
                Divider()
                HStack(alignment: .bottom, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Proje adı").font(.caption).foregroundStyle(.secondary)
                        TextField("Yeni hikâye", text: $projectName).textFieldStyle(.roundedBorder).accessibilityLabel("Proje adı")
                    }.frame(maxWidth: 300)
                    Spacer()
                    Button { model.newProject(selected, name: projectName) } label: { Label("Kurguya başla", systemImage: "arrow.right") }
                        .buttonStyle(StudioButton(prominent: true))
                }.padding(.horizontal, 28).padding(.vertical, 18).background(Studio.panel)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(Studio.background)
    }
}

struct RecoveryPanel: View {
    let model: WorkspaceModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Kaldığın yerden.").font(.system(size: 28, design: .serif)); Spacer(); Button("Kapat") { model.showRecovery = false } }
            Text("Otomatik kurtarma kopyaları ayrı bir proje olarak açılır. Asıl dosyanın üzerine yazılmaz.").font(.caption).foregroundStyle(.secondary)
            if model.recoveryEntries.isEmpty { ContentUnavailableView("Henüz kayıt yok", systemImage: "clock.arrow.circlepath") }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.recoveryEntries) { entry in
                        HStack { Image(systemName: "doc.text"); VStack(alignment: .leading) { Text(entry.name); Text(entry.date.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("Kurtar") { model.recover(entry) }.buttonStyle(StudioButton()) }.padding(12).background(Studio.raised, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }.padding(26).frame(width: 590, height: 470).background(Studio.panel)
    }
}

struct TitlesPanel: View {
    let model: WorkspaceModel
    @State private var selected: UUID?
    @State private var text = "Hikâyenin başlığı"
    @State private var start = 0.0
    @State private var duration = 3.0
    @State private var fontSize = 48.0
    @State private var vertical = 0.1
    @State private var titleStyle = TitleStyle()
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Sözcüklerine yer aç.").font(.system(size: 27, design: .serif)); Spacer(); Button("Bitti") { model.showTitles = false } }
            HStack {
                Button("SRT içe aktar", action: model.importSubtitles)
                Button("SRT dışa aktar", action: model.exportSubtitles).disabled((model.sequence.titles ?? []).isEmpty)
                Spacer()
                Menu("Şablon") {
                    Button("Başlık") { selected = nil; text = "Hikâyenin başlığı"; fontSize = 80; vertical = 0.45 }
                    Button("Alt bant") { selected = nil; text = "İsim · Açıklama"; fontSize = 48; vertical = 0.12 }
                    Button("Altyazı") { selected = nil; text = "Altyazını yaz…"; fontSize = 42; vertical = 0.05 }
                }
            }
            HStack(alignment: .top, spacing: 20) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.sequence.titles ?? []) { title in
                            Button { selected = title.id; text = title.text; start = title.start.seconds; duration = title.duration.seconds; fontSize = title.fontSize; vertical = title.vertical; titleStyle = title.style ?? TitleStyle() } label: {
                                VStack(alignment: .leading, spacing: 4) { Text(title.text).lineLimit(2); Text(String(format: "%.2f → %.2f", title.start.seconds, title.start.seconds + title.duration.seconds)).font(.caption).foregroundStyle(.secondary) }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(selected == title.id ? Studio.accent.opacity(0.12) : Studio.raised, in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }.frame(width: 220)
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $text).font(.system(size: 16)).frame(height: 120).overlay(RoundedRectangle(cornerRadius: 8).stroke(Studio.border))
                    HStack { Text("Başlangıç"); TextField("sn", value: $start, format: .number); Text("Süre"); TextField("sn", value: $duration, format: .number) }.textFieldStyle(.roundedBorder)
                    HStack { Text("Yazı boyutu"); Slider(value: $fontSize, in: 12...180); Text("\(Int(fontSize))") }
                    HStack { Text("Dikey konum"); Slider(value: $vertical, in: 0...0.8) }
                    HStack {
                        Picker("Font", selection: $titleStyle.font) { Text("Sistem").tag(TitleFont.system); Text("Serif").tag(TitleFont.serif); Text("Eş aralıklı").tag(TitleFont.monospaced) }
                        Toggle("Kalın", isOn: $titleStyle.bold)
                        Picker("Hizalama", selection: $titleStyle.alignment) { Text("Sol").tag(TitleAlignment.left); Text("Orta").tag(TitleAlignment.center); Text("Sağ").tag(TitleAlignment.right) }
                    }
                    HStack {
                        ColorPicker("Yazı", selection: colorBinding(\.foreground))
                        ColorPicker("Zemin", selection: colorBinding(\.background))
                        ColorPicker("Kontur", selection: colorBinding(\.outline))
                    }
                    HStack { Text("Kontur"); Slider(value: $titleStyle.outlineWidth, in: 0...8); Text(String(format: "%.1f", titleStyle.outlineWidth)); Toggle("Gölge", isOn: $titleStyle.shadow) }
                    Button("Stili sıfırla") { titleStyle = TitleStyle() }
                    HStack {
                        Button(selected == nil ? "Ekle" : "Güncelle") { commit() }.buttonStyle(StudioButton(prominent: true)).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || duration <= 0 || start < 0)
                        Button("Yeni") { selected = nil }
                        if let selected { Button("Sil", role: .destructive) { model.apply(.setTitles(sequenceID: model.sequence.id, titles: (model.sequence.titles ?? []).filter { $0.id != selected })); self.selected = nil } }
                    }
                    Text("Metinler önizlemede ve çıktıda görünür. Yazıyı video süresi içinde konumlandırın.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(26).frame(width: 820, height: 620).background(Studio.panel)
    }
    private func colorBinding(_ key: WritableKeyPath<TitleStyle, TitleColor>) -> Binding<Color> {
        Binding(get: {
            let value = titleStyle[keyPath: key]
            return Color(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.alpha)
        }, set: { value in
            guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return }
            titleStyle[keyPath: key] = TitleColor(rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent)
        })
    }
    func commit() {
        guard let a = model.quantized(start), let d = model.quantized(duration), d > .zero else { return }
        let title = TimelineTitle(id: selected ?? UUID(), text: text, start: a, duration: d, fontSize: fontSize, vertical: vertical, style: titleStyle)
        var titles = model.sequence.titles ?? []
        if let i = titles.firstIndex(where: { $0.id == title.id }) { titles[i] = title } else { titles.append(title) }
        if model.apply(.setTitles(sequenceID: model.sequence.id, titles: titles)) { selected = title.id }
    }
}

struct FadeControls: View {
    let model: WorkspaceModel
    let clip: Clip
    @State private var fadeIn: Double
    @State private var fadeOut: Double
    init(model: WorkspaceModel, clip: Clip) {
        self.model = model; self.clip = clip
        _fadeIn = State(initialValue: clip.fadeIn ?? 0); _fadeOut = State(initialValue: clip.fadeOut ?? 0)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SES GEÇİŞİ · SANİYE").font(.caption2)
            HStack { Text("Giriş"); TextField("Giriş", value: $fadeIn, format: .number); Text("Çıkış"); TextField("Çıkış", value: $fadeOut, format: .number) }.textFieldStyle(.roundedBorder)
            Button("Fade uygula") { model.apply(.setFades(clipID: clip.id, fadeIn: fadeIn, fadeOut: fadeOut)) }.buttonStyle(StudioButton())
                .disabled(model.selectedIsLocked || fadeIn < 0 || fadeOut < 0 || fadeIn + fadeOut > clip.duration.seconds)
        }.onChange(of: clip.fadeIn) { _, value in fadeIn = value ?? 0 }.onChange(of: clip.fadeOut) { _, value in fadeOut = value ?? 0 }
    }
}
