import Foundation
import Observation
@preconcurrency import AVFoundation
import KurguCore
import KurguMedia

/// UI observes state and attaches player to AVPlayerLayer/AVPlayerView.
@MainActor @Observable
public final class PreviewEngine {
    public let player = AVPlayer()
    public private(set) var isLoading = false
    public private(set) var lastError: String?
    public private(set) var duration = MediaTime.zero
    public private(set) var currentTime = MediaTime.zero
    public private(set) var isPlaying = false
    public var level: Float {
        guard isPlaying, let master = prepared?.audioMaster else { return 0 }
        let index = Int(Double(currentTime.value) / Double(currentTime.timescale) / master.binDuration)
        return master.peaks.indices.contains(index) ? master.peaks[index] : 0
    }
    public var itemStatus: AVPlayerItem.Status { player.currentItem?.status ?? .unknown }
    public var playbackError: Error? { player.currentItem?.error ?? player.error }
    @ObservationIgnored private var clockObservation: PlayerClockObservation?
    @ObservationIgnored private var rateObservation: NSKeyValueObservation?
    @ObservationIgnored private var prepared: PreparedPreview?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var seekGeneration = UUID()

    public init() {
        clockObservation = PlayerClockObservation(player: player) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTime = (try? MediaTime(cmTime: time)) ?? .zero
            }
        }
        rateObservation = player.observe(\.rate, options: [.initial, .new]) { [weak self] player, _ in
            let playing = player.rate != 0
            Task { @MainActor [weak self] in self?.isPlaying = playing }
        }
    }

    /// Previous preview survives a compile failure; only the latest request may replace it.
    public func load(_ project: Project, sequenceID: UUID) async throws {
        let request = UUID(); generation = request
        isLoading = true; lastError = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await TimelineCompiler().compile(project, sequenceID: sequenceID)
            try Task.checkCancellation()
            guard generation == request else { throw CancellationError() }
            player.pause()
            seekGeneration = UUID()
            player.currentItem?.cancelPendingSeeks()
            player.replaceCurrentItem(with: result.makePlayerItem())
            prepared = result
            duration = result.duration
            currentTime = .zero
        } catch {
            if generation == request, !(error is CancellationError) { lastError = String(describing: error) }
            throw error
        }
    }

    public func play() { guard prepared != nil else { return }; player.play() }
    public func pause() { player.pause() }

    /// Scrub requests use frame tolerance; the final release requests exact positioning.
    @discardableResult public func seek(to time: MediaTime, precise: Bool = true) async -> Bool {
        guard let item = player.currentItem else { return false }
        let request = UUID(); seekGeneration = request
        item.cancelPendingSeeks()
        let clamped = min(max(time, .zero), duration)
        let tolerance = precise ? CMTime.zero : CMTime(value: 1, timescale: 30)
        let finished = await player.seek(to: clamped.cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance)
        let accepted = finished && request == seekGeneration && !Task.isCancelled
        if accepted { currentTime = (try? MediaTime(cmTime: player.currentTime())) ?? .zero }
        return accepted
    }

    public func unload() {
        generation = UUID(); seekGeneration = UUID()
        player.pause(); player.currentItem?.cancelPendingSeeks()
        player.replaceCurrentItem(with: nil)
        prepared = nil; duration = .zero; currentTime = .zero; isPlaying = false; isLoading = false; lastError = nil
    }
}

/// Immutable ownership wrapper; the token is installed once and removed on destruction.
private final class PlayerClockObservation {
    private let player: AVPlayer
    private let token: Any
    init(player: AVPlayer, callback: @escaping @Sendable (CMTime) -> Void) {
        self.player = player
        token = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main, using: callback)
    }
    deinit { player.removeTimeObserver(token) }
}
