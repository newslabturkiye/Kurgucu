import SwiftUI
import AppKit
import UniformTypeIdentifiers
import KurguCore
import KurguEditing
import KurguMedia
import KurguPlayback
import KurguPersistence
import KurguExport
@preconcurrency import AVFoundation

extension MediaTime {
    var seconds: Double { Double(value) / Double(timescale) }
}

@MainActor @Observable
final class WorkspaceModel {
    var session: EditorSession
    let preview = PreviewEngine()
    let exporter = ExportEngine()
    var showHome = true
    var showTitles = false
    var showRecovery = false
    var showLibrary = true
    var showInspector = true
    var recoveryEntries: [RecoveryEntry] = []
    var recoveryStatus = "Otomatik kurtarma açık"
    var useProxies = false
    var proxyURLs: [UUID: URL] = [:]
    var proxyBusy = false
    var previewScale: Double = 1
    var filmstrips: [UUID: [NSImage]] = [:]
    var waveforms: [UUID: Waveform] = [:]
    var selectedClips: Set<UUID> = []
    var exportSettings = ExportSettings()
    var showExport = false
    var showCanvas = false
    var exportedURL: URL?
    var thumbnails: [UUID: NSImage] = [:]
    var search = ""
    var filteredAssets: [MediaAsset] {
        project.assets.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }
    var selectedAsset: UUID?
    var selectedClip: UUID?
    var selectedTrack: UUID?
    var errorMessage: String?
    var status = "Medya ekleyerek başlayın"
    var isBusy = false
    var zoom: Double = 64
    var cutTool = false
    var snappingEnabled = true
    var projectURL: URL?
    private var savedProject: Project
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private let store = ProjectStore()
    @ObservationIgnored private var recoveryTask: Task<Void, Never>?
    @ObservationIgnored let recovery = RecoveryStore(root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("n kurgu/Recovery"))
    var project: Project { session.project }
    var sequence: KurguCore.Sequence { project.sequences[0] }
    var dirty: Bool { project != savedProject }
    var clip: Clip? { sequence.tracks.flatMap(\.clips).first { $0.id == selectedClip } }
    var timelineEnd: Double { sequence.tracks.flatMap(\.clips).compactMap { try? $0.end().seconds }.max() ?? 0 }
    var activeTrack: Track? { sequence.tracks.first { $0.id == selectedTrack } }
    var selectedIsLocked: Bool { sequence.tracks.first { $0.clips.contains { $0.id == selectedClip } }?.isLocked ?? false }

    init() {
        let project = Project(name: "İsimsiz proje", sequences: [KurguCore.Sequence(tracks: [
            Track(name: "Video 1", kind: .video), Track(name: "Ses 1", kind: .audio)
        ])])
        session = try! EditorSession(project: project)
        savedProject = project
        Task { recoveryEntries = await recovery.entries() }
    }

    func setCanvas(width: Int, height: Int, fit: CanvasFit) {
        if apply(.setCanvas(sequenceID: sequence.id, width: width, height: height, fit: fit)) {
            status = "Tuval: \(CanvasPreset.ratioLabel(width: width, height: height)) · \(width) × \(height)"
        }
    }
    func assetName(_ id: UUID) -> String { project.assets.first { $0.id == id }?.name ?? "Medya" }
    @discardableResult
    func apply(_ command: EditCommand, rebuild: Bool = true) -> Bool {
        do { try session.execute(command); scheduleRecovery(); if rebuild { refreshPreview() }; return true }
        catch { report(error); return false }
    }
    func undo() { session.undo(); scheduleRecovery(); reconcile(); status = "Geri alındı"; refreshPreview() }
    func redo() { session.redo(); scheduleRecovery(); reconcile(); status = "Yinelendi"; refreshPreview() }
    private func reconcile() {
        selectedClips.formIntersection(Set(sequence.tracks.flatMap(\.clips).map(\.id)))
        if clip == nil { selectedClip = nil }
        if !sequence.tracks.contains(where: { $0.id == selectedTrack }) { selectedTrack = nil }
        if !project.assets.contains(where: { $0.id == selectedAsset }) { selectedAsset = nil }
    }
    func addTrack(_ kind: TrackKind) {
        let count = sequence.tracks.filter { $0.kind == kind }.count + 1
        let track = Track(name: "\(kind == .video ? "Video" : "Ses") \(count)", kind: kind)
        apply(.addTrack(sequenceID: sequence.id, track: track), rebuild: false)
        selectedTrack = track.id
    }
    func appendAsset(_ id: UUID) {
        guard let asset = project.assets.first(where: { $0.id == id }) else { return }
        let kind: TrackKind = asset.kind == .video ? .video : .audio
        let target = sequence.tracks.first { $0.id == selectedTrack && $0.kind == kind && !$0.isLocked }
            ?? sequence.tracks.first { $0.kind == kind && !$0.isLocked }
        guard let target else { errorMessage = "Önce uygun, kilitsiz bir iz ekleyin."; return }
        let end = target.clips.compactMap { try? $0.end() }.max() ?? .zero
        let clip = Clip(assetID: id, start: end, duration: asset.duration)
        guard apply(.insert(sequenceID: sequence.id, trackID: target.id, clip: clip)) else { return }
        selectedClip = clip.id; selectedTrack = target.id
    }
    func duplicateSelected() {
        guard let clip, let track = sequence.tracks.first(where: { $0.clips.contains(where: { $0.id == clip.id }) }) else { return }
        guard apply(.duplicate(clipID: clip.id)) else { return }
        if let copy = sequence.tracks.first(where: { $0.id == track.id })?.clips.last, copy.id != clip.id {
            selectedClip = copy.id; selectedTrack = track.id
        }
    }
    func toggleLock(_ track: Track) { apply(.setTrackLocked(trackID: track.id, locked: !track.isLocked), rebuild: false) }
    func toggleMute(_ track: Track) {
        var settings = track.audioSettings; settings.isMuted.toggle()
        apply(.setTrackAudio(trackID: track.id, settings: settings))
    }
    func setVolume(_ track: Track, volume: Double) {
        var settings = track.audioSettings; settings.volume = Float(volume)
        apply(.setTrackAudio(trackID: track.id, settings: settings))
    }
    func removeSelected(ripple: Bool = false) {
        if selectedClips.count > 1 {
            let commands = selectedClips.map { EditCommand.remove(clipID: $0) }
            if apply(.batch(commands)) { selectedClips = []; selectedClip = nil }
            return
        }
        guard let clip else { return }
        if apply(ripple ? .rippleRemove(clipID: clip.id) : .remove(clipID: clip.id)) { selectedClip = nil }
    }
    func split() {
        guard let clip else { return }
        split(clipID: clip.id, seconds: preview.currentTime.seconds)
    }
    func split(clipID: UUID, seconds: Double) {
        guard let time = quantized(seconds) else { return }
        apply(.split(clipID: clipID, at: time))
    }
    func trim(start: Double, end: Double) {
        guard let clip, let a = quantized(start), let b = quantized(end) else { return }
        apply(.trim(clipID: clip.id, start: a, end: b))
    }
    func quantized(_ seconds: Double) -> MediaTime? {
        guard seconds.isFinite, seconds >= 0, seconds < 1e9 else { return nil }
        let frame = sequence.frameDuration
        let frames = (seconds / frame.seconds).rounded()
        guard frames < Double(Int64.max / max(1, frame.value)) else { return nil }
        return try? MediaTime(Int64(frames) * frame.value, timescale: frame.timescale)
    }
    func seek(_ seconds: Double, precise: Bool = true) {
        guard let time = quantized(max(0, seconds)) else { return }
        preview.pause()
        Task { await preview.seek(to: time, precise: precise) }
    }
    func togglePlayback() {
        if preview.isPlaying { preview.pause() }
        else {
            Task {
                if preview.currentTime >= preview.duration { await preview.seek(to: .zero) }
                preview.play()
            }
        }
    }
    func detachSelectedAudio() {
        guard !isBusy, let clip, !selectedIsLocked, clip.audioDetached != true,
              let asset = project.assets.first(where: { $0.id == clip.assetID }) else { return }
        let snapshot = project
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let access = try MediaAccess(url: asset.fileURL, bookmark: asset.securityScopedBookmark)
                defer { withExtendedLifetime(access) {} }
                let source = AVURLAsset(url: access.url)
                guard let audio = try await source.loadTracks(withMediaType: .audio).first else {
                    errorMessage = "Bu klipte ayrılabilecek bir ses kanalı yok."; return
                }
                let available = try await audio.load(.timeRange)
                let overlap = CMTimeRangeGetIntersection(available, otherRange: CMTimeRange(start: clip.sourceStart.cmTime, duration: clip.duration.cmTime))
                guard overlap.isValid, overlap.duration > .zero else {
                    errorMessage = "Seçili kesitte kaynak sesi bulunmuyor."; return
                }
                guard project == snapshot else { errorMessage = "Proje değişti; ses ayırmayı tekrar deneyin."; return }
                if apply(.detachAudio(clipID: clip.id)) { status = "Ses ayrı ize alındı; video sesi iki kez çalmaz." }
            } catch { report(error) }
        }
    }
    func refreshPreview() {
        renderTask?.cancel()
        var snapshot = project
        if useProxies {
            for i in snapshot.assets.indices {
                if let proxy = proxyURLs[snapshot.assets[i].id] { snapshot.assets[i].fileURL = proxy; snapshot.assets[i].securityScopedBookmark = nil }
            }
        }
        if previewScale < 1 {
            snapshot.sequences[0].width = max(2, Int(Double(sequence.width) * previewScale) / 2 * 2)
            snapshot.sequences[0].height = max(2, Int(Double(sequence.height) * previewScale) / 2 * 2)
        }
        let position = preview.currentTime
        preview.pause()
        guard timelineEnd > 0 else { preview.unload(); return }
        renderTask = Task {
            do {
                try await preview.load(snapshot, sequenceID: snapshot.sequences[0].id)
                try Task.checkCancellation()
                await preview.seek(to: position)
                status = "Önizleme hazır"
            } catch is CancellationError {} catch {
                guard !Task.isCancelled else { return }
                preview.unload()
                report(error)
            }
        }
    }
    func importMedia() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .audio, .image]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        showHome = false
        importURLs(panel.urls)
    }
    func importURLs(_ urls: [URL]) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            for url in urls {
                do {
                    let input: URL
                    let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
                    if isImage {
                        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("kurgucu/Stills")
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        input = folder.appendingPathComponent(UUID().uuidString + ".mov")
                        try await StillImageVideo.create(source: url, destination: input)
                    } else { input = url }
                    let result = try await MediaImporter().inspect(input, persistAccess: true)
                    var imported = result.asset
                    if isImage { imported.name = url.lastPathComponent + " · Fotoğraf (5 sn)" }
                    apply(.addAsset(imported), rebuild: false)
                    selectedAsset = result.asset.id
                    status = "İçe aktarıldı: \(result.asset.name)"
                    await loadThumbnail(result.asset)
                    await analyze(result.asset)
                } catch { report(error) }
            }
        }
    }
    func loadThumbnail(_ asset: MediaAsset) async {
        guard asset.kind == .video, thumbnails[asset.id] == nil else { return }
        do {
            let access = try MediaAccess(url: asset.fileURL, bookmark: asset.securityScopedBookmark)
            defer { withExtendedLifetime(access) {} }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: access.url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 320, height: 180)
            let result = try await generator.image(at: .zero)
            thumbnails[asset.id] = NSImage(cgImage: result.image, size: .zero)
        } catch { /* Import stays usable when a thumbnail cannot be decoded. */ }
    }
    func exportVideo() {
        guard !exporter.isExporting else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = exportSettings.codec == .proRes ? [.quickTimeMovie] : [.mpeg4Movie]
        panel.nameFieldStringValue = (projectURL?.deletingPathExtension().lastPathComponent ?? project.name) + "." + exportSettings.extensionName
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let snapshot = project, settings = exportSettings
        Task {
            do {
                try await exporter.export(snapshot, sequenceID: snapshot.sequences[0].id, to: url, replaceExisting: true, settings: settings)
                exportedURL = url; status = "Çıktı dosyası hazır"
            } catch is CancellationError { status = "Dışa aktarma iptal edildi" }
            catch { showExport = false; report(error) }
        }
    }
    func save(asNew: Bool = false) async -> Bool {
        var destination = asNew ? nil : projectURL
        if destination == nil {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = project.name + ".nkurgu"
            panel.allowedContentTypes = [UTType(exportedAs: "com.nkurgu.project", conformingTo: .package)]
            guard panel.runModal() == .OK else { return false }
            destination = panel.url
        }
        guard let destination else { return false }
        let snapshot = project
        do {
            try await store.save(snapshot, to: destination)
            savedProject = snapshot; projectURL = destination
            status = "Proje kaydedildi"
            return true
        } catch { report(error); return false }
    }
    func confirmUnsaved() async -> Bool {
        guard dirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Değişiklikler kaydedilsin mi?"
        alert.informativeText = "Kaydedilmemiş kurgu değişiklikleriniz var."
        alert.addButton(withTitle: "Kaydet")
        alert.addButton(withTitle: "Vazgeç")
        alert.addButton(withTitle: "Kaydetmeden devam et")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return await save()
        case .alertThirdButtonReturn: return true
        default: return false
        }
    }
    func openProject() {
        Task {
            guard await confirmUnsaved() else { return }
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [UTType(exportedAs: "com.nkurgu.project", conformingTo: .package)]
            panel.canChooseDirectories = false
            panel.treatsFilePackagesAsDirectories = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            isBusy = true
            defer { isBusy = false }
            do {
                let loaded = try await store.load(from: url)
                session = try EditorSession(project: loaded)
                savedProject = loaded; projectURL = url
                selectedClip = nil; selectedAsset = nil; selectedTrack = nil
                selectedClips = []; preview.unload(); refreshPreview()
                thumbnails.removeAll()
                showHome = false
                for asset in loaded.assets { await loadThumbnail(asset); await analyze(asset) }
            } catch { report(error) }
        }
    }
    func scheduleRecovery() {
        recoveryTask?.cancel()
        let snapshot = project
        recoveryTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(800))
                try Task.checkCancellation()
                try await recovery.checkpoint(snapshot)
                recoveryStatus = "Kurtarma kopyası kaydedildi"
            } catch is CancellationError {} catch { recoveryStatus = "Kurtarma kaydı başarısız: \(error.localizedDescription)" }
        }
    }
    func flushRecovery() async {
        recoveryTask?.cancel()
        if dirty { do { try await recovery.checkpoint(project) } catch { recoveryStatus = "Kurtarma kaydı başarısız" } }
    }
    func recover(_ entry: RecoveryEntry) {
        Task {
            guard await confirmUnsaved() else { return }
            do {
                let restored = try await recovery.restore(entry)
                session = try EditorSession(project: restored); projectURL = nil
                selectedClip = nil; selectedTrack = nil; selectedClips = []
                showHome = false; showRecovery = false; refreshPreview()
                for asset in restored.assets { await loadThumbnail(asset); await analyze(asset) }
            } catch { report(error) }
        }
    }
    func newProject(_ preset: CanvasPreset, name: String? = nil) {
        Task {
            guard await confirmUnsaved() else { return }
            let title = name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let project = Project(name: title?.isEmpty == false ? title! : preset.label, sequences: [KurguCore.Sequence(width: preset.width, height: preset.height, tracks: [Track(name: "Video 1", kind: .video), Track(name: "Ses 1", kind: .audio)])])
            session = try! EditorSession(project: project); savedProject = project; projectURL = nil
            selectedClip = nil; selectedTrack = nil; selectedClips = []
            preview.unload(); showHome = false
        }
    }
    func analyze(_ asset: MediaAsset) async {
        do {
            let access = try MediaAccess(url: asset.fileURL, bookmark: asset.securityScopedBookmark)
            defer { withExtendedLifetime(access) {} }
            waveforms[asset.id] = try await AudioAnalysis.waveform(url: access.url)
            if asset.kind == .video, filmstrips[asset.id] == nil {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: access.url))
                generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 160, height: 90)
                var images: [NSImage] = []
                for i in 0..<12 {
                    let frame = try await generator.image(at: CMTime(seconds: asset.duration.seconds * Double(i) / 12, preferredTimescale: 60000))
                    images.append(NSImage(cgImage: frame.image, size: .zero))
                }
                filmstrips[asset.id] = images
            }
        } catch { status = "Medya hazır; bazı küçük resimler veya ses analizi üretilemedi." }
    }
    func buildProxies() {
        guard !proxyBusy else { return }; proxyBusy = true
        let assets = project.assets.filter { $0.kind == .video && proxyURLs[$0.id] == nil }
        Task {
            defer { proxyBusy = false }
            do {
                let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("n kurgu/Proxies")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                for asset in assets {
                    let access = try MediaAccess(url: asset.fileURL, bookmark: asset.securityScopedBookmark)
                    defer { withExtendedLifetime(access) {} }
                    let values = try access.url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let key = "\(asset.id)-\(values.fileSize ?? 0)-\(Int(values.contentModificationDate?.timeIntervalSince1970 ?? 0))"
                    let destination = directory.appendingPathComponent(key + ".mov")
                    status = "Proxy hazırlanıyor: \(asset.name)"
                    if !FileManager.default.fileExists(atPath: destination.path) {
                        do { try await ProxyBuilder.build(source: access.url, destination: destination) }
                        catch { try? FileManager.default.removeItem(at: destination); throw error }
                    }
                    proxyURLs[asset.id] = destination
                }
                useProxies = true; refreshPreview()
            } catch { report(error) }
        }
    }
    func dropAsset(_ id: UUID, trackID: UUID, seconds: Double) -> Bool {
        guard let asset = project.assets.first(where: { $0.id == id }), let start = quantized(max(0, seconds)) else { return false }
        let clip = Clip(assetID: id, start: start, duration: asset.duration)
        guard apply(.insert(sequenceID: sequence.id, trackID: trackID, clip: clip)) else { return false }
        selectedClip = clip.id; selectedTrack = trackID; return true
    }
    func importSubtitles() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "srt") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let titles = try SubtitleFile.parse(String(contentsOf: url, encoding: .utf8)); apply(.setTitles(sequenceID: sequence.id, titles: (sequence.titles ?? []) + titles)) } catch { report(error) }
    }
    func exportSubtitles() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Altyazilar.srt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try SubtitleFile.encode(sequence.titles ?? []).write(to: url, atomically: true, encoding: .utf8) } catch { report(error) }
    }
    func report(_ error: Error) {
        errorMessage = "İşlem tamamlanamadı: \(error.localizedDescription)\n\(String(describing: error))"
    }
}
