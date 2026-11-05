import AVFoundation
import MediaPlayer
import Observation
import YouTubeKit

@MainActor
@Observable
final class Player {
    let av = AVPlayer()
    var title: String?
    var error: String?
    var last: String?
    var id: String?
    var video: YouTube?
    var file: URL?
    var loading = false

    @ObservationIgnored private var observers: [NSKeyValueObservation] = []
    @ObservationIgnored private var ticker: Any?
    @ObservationIgnored private let positions = Positions()

    init() {
        av.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        commands()
        observers.append(av.observe(\.rate) { [weak self] av, _ in
            Task { @MainActor in
                if av.rate == 0 { self?.save() }
                self?.nowPlaying()
            }
        })
        ticker = av.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 1), queue: .main) { [weak self] _ in
            Task { @MainActor in self?.save() }
        }
    }

    func play(_ text: String) async {
        last = text
        reset()
        guard let link = Link(text) else {
            fail("Not a YouTube URL: \(text)")
            return
        }
        do {
            let video = YouTube(videoID: link.id, methods: [.local, .remote])
            try load(try await Self.stream(video), start: positions.start(link.id, link: link.start))
            self.video = video
            id = link.id
            title = try await video.metadata?.title
            nowPlaying()
        } catch {
            fail("\(error)")
        }
    }

    func play(_ item: Download, at url: URL) {
        reset()
        id = item.id
        file = url
        title = item.title
        do {
            try load(url, start: positions.start(item.id, link: nil))
        } catch {
            fail("\(error)")
        }
        nowPlaying()
    }

    func stop() {
        reset()
        loading = false
        av.replaceCurrentItem(with: nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func save() {
        guard let id, let item = av.currentItem, item.status == .readyToPlay else { return }
        positions.save(id, at: item.currentTime().seconds, duration: item.duration.seconds)
    }

    private func reset() {
        save()
        loading = true
        error = nil
        title = nil
        id = nil
        video = nil
        file = nil
    }

    private func load(_ url: URL, start: Double) throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: url)
        observers.append(item.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in self?.status(item, start: start) }
        })
        av.pause()
        av.replaceCurrentItem(with: item)
    }

    static func stream(_ video: YouTube) async throws -> URL {
        if let s = Downloads.file(try await video.streams) {
            return s.url
        }
        if let s = try await video.livestreams.first(where: { $0.streamType == .hls }) {
            return s.url
        }
        throw PlayError.noStream
    }

    private func status(_ item: AVPlayerItem, start: Double) {
        guard item === av.currentItem else { return }
        switch item.status {
        case .readyToPlay:
            loading = false
            guard av.rate == 0, item.currentTime().seconds < 1 else { return }
            av.seek(to: CMTime(seconds: start, preferredTimescale: 600)) { [weak self] _ in
                Task { @MainActor in
                    self?.av.play()
                    self?.nowPlaying()
                }
            }
        case .failed:
            fail(item.error.map { "\($0)" } ?? "Playback failed")
        default:
            break
        }
    }

    private func fail(_ message: String) {
        error = message
        loading = false
    }

    private func seek(_ seconds: Double) {
        av.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600)) { [weak self] _ in
            Task { @MainActor in self?.nowPlaying() }
        }
    }

    private func nowPlaying() {
        guard let item = av.currentItem else { return }
        var info: [String: Any] = [
            MPNowPlayingInfoPropertyElapsedPlaybackTime: item.currentTime().seconds,
            MPNowPlayingInfoPropertyPlaybackRate: av.rate,
        ]
        if let title { info[MPMediaItemPropertyTitle] = title }
        if item.duration.isNumeric { info[MPMediaItemPropertyPlaybackDuration] = item.duration.seconds }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func commands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.av.play(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.av.pause(); return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let av = self?.av else { return .commandFailed }
            av.rate == 0 ? av.play() : av.pause()
            return .success
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] e in
            guard let e = e as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(e.positionTime)
            return .success
        }
        c.skipForwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipForwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            seek(av.currentTime().seconds + 15)
            return .success
        }
        c.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            seek(av.currentTime().seconds - 15)
            return .success
        }
    }
}

enum PlayError: LocalizedError {
    case noStream
    var errorDescription: String? { "No playable stream found" }
}
