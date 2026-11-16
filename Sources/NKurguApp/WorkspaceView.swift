import SwiftUI
import AVKit
import KurguCore

struct WorkspaceView: View {
    @Bindable var model: WorkspaceModel
    @State private var section: EditorSection = .media
    @AppStorage("studioAppearance") private var appearance = "system"
    var body: some View {
        VStack(spacing: 0) {
            if model.showHome { StudioHome(model: model) } else {
            EditorSectionBar(selection: $section) { model.showLibrary = true; model.selectedAsset = nil }
            VSplitView {
            HSplitView {
                if model.showLibrary { sectionPanel.frame(minWidth: 230, idealWidth: 260, maxWidth: 320).background(Studio.panel) }
                PreviewPanel(model: model).frame(minWidth: 360, maxWidth: .infinity)
                if model.showInspector { inspector.frame(minWidth: 240, idealWidth: 260, maxWidth: 300).background(Studio.panel) }
            }.frame(minHeight: 320)
            TimelinePanel(model: model).frame(minHeight: 200, idealHeight: 270)
            }
            HStack {
                Circle().fill(model.preview.isLoading ? Color.orange : Studio.accent).frame(width: 6, height: 6)
                Text(model.preview.isLoading ? "Önizleme hazırlanıyor…" : model.status)
                Spacer()
                Text("\(model.sequence.width) × \(model.sequence.height)  ·  \(1 / model.sequence.frameDuration.seconds, specifier: "%.2f") fps")
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 16).frame(height: 30)
            }
        }
        .background(Studio.background)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 10) {
                    StudioLogo(size: 36).scaleEffect(1.3)
                    Text("kurgucu").font(.headline)
                    Divider().frame(height: 18)
                    Text(model.projectURL?.deletingPathExtension().lastPathComponent ?? model.project.name).foregroundStyle(.secondary)
                    if model.dirty { Circle().fill(Studio.accent).frame(width: 6, height: 6).help("Kaydedilmemiş değişiklikler") }
                }
            }
            ToolbarItemGroup {
                Button { model.showHome.toggle() } label: { Image(systemName: "house") }.help("Başlangıç")
                Button { model.showTitles = true } label: { Label("Metin", systemImage: "textformat") }.help("Metin ve altyazı")
                Menu {
                    Toggle("Medya havuzu", isOn: $model.showLibrary)
                    Toggle("Özellikler", isOn: $model.showInspector)
                    Button("Kurtarma kayıtları") { Task { model.recoveryEntries = await model.recovery.entries(); model.showRecovery = true } }
                    Button(model.proxyBusy ? "Proxy hazırlanıyor…" : "720p proxy oluştur", action: model.buildProxies).disabled(model.proxyBusy || model.project.assets.isEmpty)
                    Toggle("Proxy ile önizle", isOn: $model.useProxies).onChange(of: model.useProxies) { model.refreshPreview() }
                    Picker("Önizleme kalitesi", selection: $model.previewScale) {
                        Text("Tam").tag(1.0); Text("Yarım").tag(0.5); Text("Çeyrek").tag(0.25)
                    }.onChange(of: model.previewScale) { model.refreshPreview() }
                } label: { Image(systemName: "rectangle.3.group") }.help("Çalışma alanı ve performans")
                Menu {
                    Picker("Görünüm", selection: $appearance) {
                        Text("Sistem").tag("system")
                        Text("Açık").tag("light")
                        Text("Koyu").tag("dark")
                    }
                } label: { Image(systemName: "circle.lefthalf.filled") }.help("Görünüm")
                Button(action: model.importMedia) { StudioLabel(title: "Medya ekle", glyph: .add) }.disabled(model.isBusy)
                Button { Task { await model.save() } } label: { Label("Kaydet", systemImage: "square.and.arrow.down") }.disabled(model.isBusy)
                Button { model.exportedURL = nil; model.showExport = true } label: {
                    StudioLabel(title: "Dışa aktar", glyph: .export)
                }.labelStyle(.titleAndIcon).buttonStyle(StudioButton(prominent: true)).disabled(model.timelineEnd == 0 || model.isBusy)
            }
        }
        .sheet(isPresented: $model.showRecovery) { RecoveryPanel(model: model) }
        .sheet(isPresented: $model.showTitles) { TitlesPanel(model: model) }
        .sheet(isPresented: $model.showCanvas) { CanvasSheet(model: model) }
        .sheet(isPresented: $model.showExport) { ExportSheet(model: model) }
        .alert("İşlem tamamlanamadı", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Tamam") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .background(WindowGuard(model: model))
    }
    @ViewBuilder private var sectionPanel: some View {
        if section == .media || section == .audio { library }
        else if section == .stickers { OverlayPanel(model: model) }
        else if [.adjustment, .filters, .effects, .transitions].contains(section), let clip = model.clip, model.activeTrack?.kind == .video {
            VisualTools(model: model, section: section, clip: clip).id(clip.id)
        } else if [.filters, .effects, .transitions].contains(section) {
            VStack(spacing: 14) { Image(systemName: section.symbol).font(.largeTitle); Text("Timeline’dan bir video klibi seç.").multilineTextAlignment(.center) }.padding(20)
        } else { SectionTools(section: section, model: model) }
    }
    private var sectionAssets: [MediaAsset] {
        model.filteredAssets.filter { section != .audio || $0.kind == .audio }
    }
    private var library: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle(section == .audio ? "SES HAVUZU" : "MEDYA HAVUZU", symbol: "square.stack.3d.up")
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Medyada ara", text: $model.search).textFieldStyle(.plain)
                if model.isBusy { ProgressView().controlSize(.mini) }
            }.font(.system(size: 12)).padding(10).background(Studio.raised, in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 14)
            HStack {
                Text("PROJE DOSYALARI").tracking(1)
                Spacer()
                Text("\(sectionAssets.count)").monospacedDigit()
            }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).padding(16)
            if sectionAssets.isEmpty {
                ScrollView { VStack(spacing: 10) {
                    StudioIcon(glyph: .add, size: 48)
                    Text("Görüntü. Ses. Başlangıç.").font(.system(size: 13, weight: .medium))
                    Text("Dosyalarını buraya bırak\nveya medya ekle.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Studio.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    .padding(14) }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(sectionAssets) { asset in
                            Button { model.selectedAsset = asset.id } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Rectangle().fill(Studio.background).frame(height: 105)
                                        if let image = model.thumbnails[asset.id] {
                                            Image(nsImage: image).resizable().scaledToFill().frame(height: 105).clipped()
                                        } else {
                                            StudioIcon(glyph: asset.kind == .video ? .media : .audio, size: 66).frame(maxWidth: .infinity, minHeight: 105)
                                        }
                                        Text(String(format: "%.2f s", asset.duration.seconds)).font(.system(size: 10, design: .monospaced)).padding(5).foregroundStyle(.white).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4)).padding(7)
                                    }
                                    HStack {
                                        StudioIcon(glyph: asset.kind == .video ? .media : .audio, size: 18)
                                        Text(asset.name).lineLimit(1)
                                        Spacer(minLength: 0)
                                    }.font(.system(size: 11, weight: .medium)).padding(10)
                                }.background(Studio.raised).clipShape(RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(model.selectedAsset == asset.id ? Studio.accent : Studio.border, lineWidth: 1))
                            }.buttonStyle(.plain).overlay { AssetDragSource(id: asset.id, image: model.thumbnails[asset.id], select: { model.selectedAsset = asset.id }) }
                            .contextMenu { Button("Timeline’a ekle") { model.appendAsset(asset.id) } }
                        }
                    }.padding(.horizontal, 14)
                }
            }
            Spacer(minLength: 8)
            Button { if let id = model.selectedAsset { model.appendAsset(id) } } label: {
                Label("Timeline’a ekle", systemImage: "plus.rectangle.on.rectangle").frame(maxWidth: .infinity)
            }.buttonStyle(StudioButton()).disabled(model.selectedAsset == nil || model.isBusy).padding(14)
        }.dropDestination(for: URL.self) { urls, _ in
            guard !model.isBusy else { return false }
            model.importURLs(urls); return true
        }
    }
    private var inspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelTitle("ÖZELLİKLER", symbol: "slider.horizontal.3")
            if let track = model.activeTrack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        TrackInspector(model: model, track: track).id(track.id)
                        if let clip = model.clip {
                            Divider().padding(.horizontal, 16)
                            ClipInspector(model: model, clip: clip).id("\(clip.id)-\(clip.start)-\(clip.duration)")
                        }
                    }.padding(.bottom, 20)
                }
            } else {
                VStack(spacing: 14) {
                    StudioIcon(glyph: .inspector, size: 76)
                    Text("Her ayrıntı senin elinde.").font(.system(size: 13, weight: .medium))
                    Text("Bir iz veya klip seç; sesini ayarla,\nkesitini düzenle.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 38)
            }
            Spacer(minLength: 0)
        }
    }
}

func panelTitle(_ title: String, symbol: String) -> some View {
    HStack(spacing: 8) { StudioIcon(glyph: symbol == "slider.horizontal.3" ? .inspector : .media, size: 22); Text(title).tracking(1.2); Spacer() }
        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(16)
}

struct ClipInspector: View {
    let model: WorkspaceModel
    let clip: Clip
    @State private var start: Double
    @State private var end: Double
    init(model: WorkspaceModel, clip: Clip) {
        self.model = model; self.clip = clip
        _start = State(initialValue: clip.start.seconds)
        _end = State(initialValue: (try? clip.end().seconds) ?? 0)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { StudioIcon(glyph: .cut, size: 22); Text("KLİP").font(.system(size: 10, weight: .semibold)).tracking(1); Spacer() }.foregroundStyle(.secondary)
            Text(model.assetName(clip.assetID)).font(.headline).lineLimit(3)
            Button(action: model.duplicateSelected) { Label("İzin sonunda çoğalt", systemImage: "plus.square.on.square") }
                .buttonStyle(StudioButton()).disabled(model.selectedIsLocked).help("⌘D · Kaynak aralığını koruyarak çoğalt")
            if model.activeTrack?.kind == .video {
                FramingInspector(model: model, clip: clip).id(clip.id)
            }
            ClipAudioAndSlip(model: model, clip: clip).id(clip.id)
            FadeControls(model: model, clip: clip).id("fade-\(clip.id)-\(clip.duration)")
            LabeledContent("Kaynak girişi", value: String(format: "%.3f sn", clip.sourceStart.seconds))
            LabeledContent("Süre", value: String(format: "%.3f sn", clip.duration.seconds))
            Divider()
            Text("KESİTİ KISALT").font(.caption2).foregroundStyle(.secondary)
            Text("GİRİŞ / ÇIKIŞ · SANİYE").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            TextField("Başlangıç (sn)", value: $start, format: .number.precision(.fractionLength(3))).textFieldStyle(.roundedBorder)
            TextField("Bitiş (sn)", value: $end, format: .number.precision(.fractionLength(3))).textFieldStyle(.roundedBorder)
            Button("Kısaltmayı uygula") { model.trim(start: start, end: end) }.buttonStyle(StudioButton()).disabled(model.selectedIsLocked)
            Text("Zamanlar timeline üzerindedir. Mevcut kesitin içinden bir aralık seçin.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Button(role: .destructive, action: { model.removeSelected() }) { Label("Klibi kaldır", systemImage: "trash") }.disabled(model.selectedIsLocked)
            Button { model.removeSelected(ripple: true) } label: { Label("Boşluğu kapatarak kaldır", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") }.disabled(model.selectedIsLocked)
            Button { model.split() } label: { StudioLabel(title: "Oynatma başında böl", glyph: .cut) }.disabled(model.selectedIsLocked)
        }.font(.system(size: 12)).padding(.horizontal, 16)
    }
}

struct PreviewPanel: View {
    let model: WorkspaceModel
    @State private var showSafeArea = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ÖNİZLEME").font(.system(size: 10, weight: .semibold)).tracking(1)
                Spacer()
                Menu {
                    ForEach(CanvasPreset.allCases) { preset in
                        Button("\(preset.ratio) · \(preset.label)") { model.setCanvas(width: preset.width, height: preset.height, fit: model.sequence.fitMode) }
                    }
                    Divider()
                    Button("Tuval ayarları…") { model.showCanvas = true }
                } label: {
                    Label(CanvasPreset.ratioLabel(width: model.sequence.width, height: model.sequence.height), systemImage: "aspectratio")
                }.fixedSize().help("Tuval oranını değiştir").disabled(model.isBusy)
                Button { showSafeArea.toggle() } label: { Image(systemName: "viewfinder").foregroundStyle(showSafeArea ? Studio.accent : .secondary) }.buttonStyle(.plain).help("%10 güvenli alan kılavuzu; çıktıya eklenmez")
                Button { model.showCanvas = true } label: { Image(systemName: "slider.horizontal.3") }.buttonStyle(.plain).help("Tuval boyutu ve yerleşim")
            }.padding(.horizontal, 16).frame(height: 48)
            ZStack {
                Studio.raised
                if model.preview.player.currentItem != nil {
                    GeometryReader { geometry in
                        let ratio = CGFloat(model.sequence.width) / CGFloat(model.sequence.height)
                        let width = min(geometry.size.width - 16, (geometry.size.height - 16) * ratio)
                        let height = width / ratio
                        InteractivePlayer(model: model)
                            .frame(width: max(1, width), height: max(1, height))
                            .overlay {
                                if showSafeArea {
                                    Rectangle().stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                        .padding(.horizontal, max(0, width * 0.1)).padding(.vertical, max(0, height * 0.1)).allowsHitTesting(false)
                                }
                            }
                            .overlay(Rectangle().stroke(Studio.border, lineWidth: 1))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    WelcomeArtwork(importAction: model.importMedia)
                }
                if model.preview.isLoading { ProgressView().padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12)) }
            }.clipShape(RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 12)
            HStack(spacing: 18) {
                Button { model.seek(0) } label: { Image(systemName: "backward.end.fill") }.help("Başa git")
                Button(action: model.togglePlayback) { Image(systemName: model.preview.isPlaying ? "pause.fill" : "play.fill").frame(width: 34, height: 34).foregroundStyle(Studio.onAccent).background(Studio.accent, in: Circle()) }.help("Oynat / duraklat")
                Text(String(format: "%07.2f / %07.2f", model.preview.currentTime.seconds, model.preview.duration.seconds))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                AudioMeter(level: model.preview.level)
                Text("\(model.sequence.width)×\(model.sequence.height)").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            }.buttonStyle(.plain).padding(16).disabled(model.timelineEnd == 0 || model.preview.isLoading)
        }
    }
}

