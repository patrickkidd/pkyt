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

    @ObservationIgnored private var observers: [NSKeyValueObservation] = []

    init() {
        av.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        commands()
        observers.append(av.observe(\.rate) { [weak self] _, _ in
            Task { @MainActor in self?.nowPlaying() }
        })
    }

    func play(_ text: String) async {
        last = text
        error = nil
        title = nil
        guard let link = Link(text) else {
            error = "Not a YouTube URL: \(text)"
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            let video = YouTube(videoID: link.id, methods: [.local, .remote])
            let item = AVPlayerItem(url: try await Self.stream(video))
            observers.append(item.observe(\.status) { [weak self] item, _ in
                Task { @MainActor in self?.status(item, start: link.start) }
            })
            av.replaceCurrentItem(with: item)
            title = try await video.metadata?.title
            nowPlaying()
        } catch {
            self.error = "\(error)"
        }
    }

    static func stream(_ video: YouTube) async throws -> URL {
        let streams = try await video.streams.filter(\.isNativelyPlayable)
        if let s = streams.filterVideoAndAudio().highestResolutionStream() {
            return s.url
        }
        if let s = streams.filterAudioOnly().highestAudioBitrateStream() {
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
            guard av.rate == 0, item.currentTime().seconds < 1 else { return }
            av.seek(to: CMTime(seconds: start, preferredTimescale: 600)) { [weak self] _ in
                Task { @MainActor in
                    self?.av.play()
                    self?.nowPlaying()
                }
            }
        case .failed:
            error = item.error.map { "\($0)" } ?? "Playback failed"
        default:
            break
        }
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
