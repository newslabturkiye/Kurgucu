import SwiftUI
import AppKit

@main struct NKurguApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = WorkspaceModel()
    @AppStorage("studioAppearance") private var appearance = "system"
    var body: some Scene {
        Window("kurgucu", id: "workspace") {
            WorkspaceView(model: model)
                .frame(minWidth: 1040, minHeight: 680)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
                .tint(Studio.accent)
                .onAppear { delegate.model = model; NSApp.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 1320, height: 820)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("kurgucu Hakkında", action: DeveloperCredits.showAbout)
            }
            CommandGroup(replacing: .newItem) {
                Button("Proje aç…", action: model.openProject).keyboardShortcut("o").disabled(model.isBusy)
                Button("Medya ekle…", action: model.importMedia).keyboardShortcut("i").disabled(model.isBusy)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Kaydet") { Task { await model.save() } }.keyboardShortcut("s").disabled(model.isBusy)
                Button("Farklı kaydet…") { Task { await model.save(asNew: true) } }.keyboardShortcut("s", modifiers: [.command, .shift]).disabled(model.isBusy)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Geri al", action: model.undo).keyboardShortcut("z").disabled(!model.session.canUndo || model.isBusy)
                Button("Yinele", action: model.redo).keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!model.session.canRedo || model.isBusy)
            }
            CommandMenu("Kurgu") {
                Button("Tuval ve oran…") { model.showCanvas = true }.keyboardShortcut("r", modifiers: [.command, .shift]).disabled(model.isBusy)
                Button("MP4 dışa aktar…") { model.exportedURL = nil; model.showExport = true }
                    .keyboardShortcut("e").disabled(model.timelineEnd == 0 || model.isBusy)
                Button("Seçili klibi çoğalt", action: model.duplicateSelected).keyboardShortcut("d").disabled(model.clip == nil || model.selectedIsLocked || model.isBusy)
                Button("Seçili videonun sesini ayır", action: model.detachSelectedAudio)
                    .disabled(model.clip == nil || model.activeTrack?.kind != .video || model.clip?.audioDetached == true || model.selectedIsLocked || model.isBusy)
                Button("Seçili klibi böl", action: model.split).keyboardShortcut("b").disabled(model.clip == nil || model.selectedIsLocked || model.isBusy)
            }
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: WorkspaceModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        if model.isBusy || model.exporter.isExporting { return .terminateCancel }
        Task { await model.flushRecovery(); sender.reply(toApplicationShouldTerminate: await model.confirmUnsaved()) }
        return .terminateLater
    }
}

struct WindowGuard: NSViewRepresentable {
    let model: WorkspaceModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view, coordinator = context.coordinator] in
            view?.window?.delegate = coordinator
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.isDocumentEdited = model.dirty
    }
    @MainActor final class Coordinator: NSObject, NSWindowDelegate {
        let model: WorkspaceModel
        private var pending = false
        init(model: WorkspaceModel) { self.model = model }
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard !model.isBusy, !model.exporter.isExporting, !pending else { return false }
            guard model.dirty else { model.preview.pause(); return true }
            pending = true
            Task {
                defer { pending = false }
                if await model.confirmUnsaved() { model.preview.pause(); sender.close() }
            }
            return false
        }
    }
}
