import SwiftUI
import KurguCore

struct CanvasSheet: View {
    @Bindable var model: WorkspaceModel
    @State private var width: Int
    @State private var height: Int
    init(model: WorkspaceModel) {
        self.model = model
        _width = State(initialValue: model.sequence.width)
        _height = State(initialValue: model.sequence.height)
    }
    private var valid: Bool { (64...4096).contains(width) && (64...4096).contains(height) && width.isMultiple(of: 2) && height.isMultiple(of: 2) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Her ekrana uygun.").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("Oranı seç. Kadrajını düzenle. Aynı ölçülerde dışa aktar.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Bitti") { model.showCanvas = false }.buttonStyle(StudioButton(prominent: true)).keyboardShortcut(.defaultAction)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(CanvasPreset.allCases) { preset in
                    Button {
                        model.setCanvas(width: preset.width, height: preset.height, fit: model.sequence.fitMode)
                    } label: {
                        VStack(spacing: 9) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4).fill(Studio.accent.opacity(0.12))
                                RoundedRectangle(cornerRadius: 4).stroke(Studio.accent, lineWidth: 2)
                            }.aspectRatio(CGFloat(preset.width) / CGFloat(preset.height), contentMode: .fit).frame(width: 58, height: 50)
                            Text(preset.ratio).font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text(preset.label).font(.system(size: 10)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Studio.raised, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(CanvasPreset.ratioLabel(width: model.sequence.width, height: model.sequence.height) == preset.ratio ? Studio.accent : Studio.border, lineWidth: 1.5))
                    }.buttonStyle(.plain).accessibilityLabel("\(preset.ratio), \(preset.width) × \(preset.height)")
                }
                Button {
                    model.setCanvas(width: model.sequence.height, height: model.sequence.width, fit: model.sequence.fitMode)
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 27, weight: .light)).frame(height: 50)
                        Text("Yönü çevir").font(.system(size: 12, weight: .semibold))
                        Text("Genişlik ↔ Yükseklik").font(.system(size: 9)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 14).background(Studio.raised, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            HStack(spacing: 12) {
                Text("Yerleşim").font(.system(size: 12, weight: .semibold))
                Picker("Varsayılan yerleşim", selection: Binding(get: { model.sequence.fitMode }, set: { mode in
                    model.setCanvas(width: model.sequence.width, height: model.sequence.height, fit: mode)
                })) {
                    Text("Sığdır").tag(CanvasFit.fit)
                    Text("Doldur").tag(CanvasFit.fill)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 200)
                Spacer()
                Text(CanvasPreset.ratioLabel(width: model.sequence.width, height: model.sequence.height)).font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            Text(model.sequence.fitMode == .fit ? "Sığdır: görüntünün tamamı korunur; oran farklıysa siyah boşluk kalır." : "Doldur: tuval kaplanır; taşan kenarlar kırpılır. Klip kadrajından konumu ayarlayabilirsiniz.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack {
                Text("Özel boyut").font(.system(size: 12, weight: .semibold))
                TextField("Genişlik", value: $width, format: .number.grouping(.never)).frame(width: 78).accessibilityLabel("Tuval genişliği")
                Text("×").foregroundStyle(.secondary)
                TextField("Yükseklik", value: $height, format: .number.grouping(.never)).frame(width: 78).accessibilityLabel("Tuval yüksekliği")
                Text("px").foregroundStyle(.secondary)
                Spacer()
                Button("Uygula") { model.setCanvas(width: width, height: height, fit: model.sequence.fitMode) }
                    .buttonStyle(StudioButton()).disabled(!valid || (width == model.sequence.width && height == model.sequence.height))
            }.textFieldStyle(.roundedBorder)
            HStack {
                Text(valid ? "64–4096 px · Çift sayılı ölçüler · Değişiklikler ⌘Z ile geri alınır." : "Her iki ölçü de 64–4096 arasında çift sayı olmalı.").font(.caption).foregroundStyle(valid ? Color.secondary : .orange)
                Spacer()
                Menu("4K") {
                    Button("Yatay · 3840 × 2160") { model.setCanvas(width: 3840, height: 2160, fit: model.sequence.fitMode) }
                    Button("Dikey · 2160 × 3840") { model.setCanvas(width: 2160, height: 3840, fit: model.sequence.fitMode) }
                }.fixedSize()
            }
        }.padding(26).frame(width: 610).background(Studio.panel)
            .onChange(of: model.sequence.width) { _, value in width = value }
            .onChange(of: model.sequence.height) { _, value in height = value }
    }
}

struct FramingInspector: View {
    let model: WorkspaceModel
    let clip: Clip
    @State private var framing: ClipFraming
    init(model: WorkspaceModel, clip: Clip) {
        self.model = model; self.clip = clip
        _framing = State(initialValue: clip.framing ?? ClipFraming())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KADRAJ").font(.system(size: 10, weight: .semibold)).tracking(1)
            Picker("Yerleşim", selection: Binding(get: { framing.fit?.rawValue ?? "inherit" }, set: { value in
                framing.fit = CanvasFit(rawValue: value); commit()
            })) {
                Text("Tuval ayarı").tag("inherit")
                Text("Sığdır").tag(CanvasFit.fit.rawValue)
                Text("Doldur").tag(CanvasFit.fill.rawValue)
            }.labelsHidden()
            control("Yakınlaştır", value: $framing.zoom, range: 1...4, display: "%\(Int((framing.zoom * 100).rounded()))")
            control("Yatay kadraj", value: $framing.horizontal, range: -1...1, display: String(format: "%.0f", framing.horizontal * 100))
            control("Dikey kadraj", value: $framing.vertical, range: -1...1, display: String(format: "%.0f", framing.vertical * 100))
            control("Döndürme", value: Binding(get: { framing.rotation ?? 0 }, set: { framing.rotation = $0 }), range: -180...180, display: String(format: "%.0f°", framing.rotation ?? 0))
            HStack {
                Button("−90°") { framing.rotation = normalized((framing.rotation ?? 0) - 90); commit() }
                Button("+90°") { framing.rotation = normalized((framing.rotation ?? 0) + 90); commit() }
            }
            Toggle("Yatay ayna", isOn: Binding(get: { framing.flipHorizontal ?? false }, set: { framing.flipHorizontal = $0; commit() }))
            Toggle("Dikey ayna", isOn: Binding(get: { framing.flipVertical ?? false }, set: { framing.flipVertical = $0; commit() }))
            Button("Kadrajı sıfırla") { framing = ClipFraming(); model.apply(.setFraming(clipID: clip.id, framing: nil)) }.font(.caption)
            Text("Konum, taşan veya boş kalan alan içinde ayarlanır. Kaynak görüntü değişmez.").font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(12).background(Studio.raised, in: RoundedRectangle(cornerRadius: 12))
            .disabled(model.selectedIsLocked)
            .onChange(of: clip.framing) { _, value in framing = value ?? ClipFraming() }
    }
    private func control(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, display: String) -> some View {
        VStack(spacing: 6) {
            HStack { Text(title); Spacer(); Text(display).monospacedDigit() }.font(.system(size: 11))
            Slider(value: value, in: range, onEditingChanged: { editing in if !editing { commit() } }).accessibilityLabel(title)
        }
    }
    private func normalized(_ degrees: Double) -> Double { degrees > 180 ? degrees - 360 : degrees < -180 ? degrees + 360 : degrees }
    private func commit() { model.apply(.setFraming(clipID: clip.id, framing: framing)) }
}
