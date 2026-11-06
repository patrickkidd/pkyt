import AVFoundation
import Foundation
import Observation
import YouTubeKit

enum DownloadState: Equatable {
    case none
    case active(Double)
    case done
}

private struct Job: Codable {
    let id: String
    let title: String
    let file: String

    var key: String { Download.key(id, Kind(file: file)) }

    init(id: String, title: String, file: String) {
        self.id = id
        self.title = title
        self.file = file
    }

    init(_ task: URLSessionTask) {
        self = try! JSONDecoder().decode(Job.self, from: Data(task.taskDescription!.utf8))
    }
}

@MainActor
@Observable
final class Downloads: NSObject {
    static let shared = try! Downloads(dir: .applicationSupportDirectory.appending(path: "downloads"), background: true)

    private(set) var items: [Download] = []
    private(set) var progress: [String: Double] = [:]
    var error: String?
    @ObservationIgnored var finish: (() -> Void)?
    nonisolated let dir: URL
    @ObservationIgnored private var session: URLSession!

    init(dir: URL, background: Bool = false) throws {
        self.dir = dir
        super.init()
        var target = dir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try target.setResourceValues(values)
        if FileManager.default.fileExists(atPath: index.path(percentEncoded: false)) {
            items = try JSONDecoder().decode([Download].self, from: Data(contentsOf: index))
        }
        guard background else { return }
        session = URLSession(configuration: .background(withIdentifier: "com.patrickkidd.pkyt.downloads"), delegate: self, delegateQueue: nil)
        session.getAllTasks { tasks in
            let keys = tasks.filter { $0.state == .running }.map { Job($0).key }
            Task { @MainActor in
                for key in keys where self.progress[key] == nil { self.progress[key] = 0 }
            }
        }
    }

    private var index: URL { dir.appending(path: "index.json") }

    func url(_ item: Download) -> URL { dir.appending(path: item.file) }

    func state(_ video: String, _ kind: Kind) -> DownloadState {
        let key = Download.key(video, kind)
        if let p = progress[key] { return .active(p) }
        return items.contains { $0.id == key } ? .done : .none
    }

    func begin(_ video: String, _ kind: Kind) -> Bool {
        guard state(video, kind) == .none else { return false }
        progress[Download.key(video, kind)] = 0
        error = nil
        return true
    }

    func start(_ video: String, title: String, kind: Kind, source: YouTube? = nil) async {
        guard begin(video, kind) else { return }
        do {
            let source = source ?? YouTube(videoID: video, methods: [.local, .remote])
            guard let stream = Self.stream(try await source.streams, kind) else { throw DownloadError.missing(kind) }
            let job = Job(id: video, title: title, file: "\(video).\(stream.fileExtension.rawValue)")
            let task = session.downloadTask(with: stream.url)
            task.taskDescription = String(decoding: try JSONEncoder().encode(job), as: UTF8.self)
            task.resume()
        } catch {
            fail(Download.key(video, kind), error)
        }
    }

    func add(_ item: Download) throws {
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i] = item
        } else {
            items.insert(item, at: 0)
        }
        progress[item.id] = nil
        try save()
    }

    func delete(_ item: Download) throws {
        try FileManager.default.removeItem(at: url(item))
        items.removeAll { $0.id == item.id }
        try save()
    }

    func move(from source: IndexSet, to destination: Int) throws {
        items.move(fromOffsets: source, toOffset: destination)
        try save()
    }

    func next(after item: Download) -> Download? {
        guard let i = items.firstIndex(where: { $0.id == item.id }), i + 1 < items.count else { return nil }
        return items[i + 1]
    }

    static func stream(_ streams: [YouTubeKit.Stream], _ kind: Kind) -> YouTubeKit.Stream? {
        let s = streams.filter(\.isNativelyPlayable)
        switch kind {
        case .audio: return s.filterAudioOnly().filter { $0.fileExtension == .m4a }.highestAudioBitrateStream()
        case .video: return s.filterVideoAndAudio().filter { $0.fileExtension == .mp4 }.highestResolutionStream()
        }
    }

    private func save() throws {
        try JSONEncoder().encode(items).write(to: index, options: .atomic)
    }

    private func fail(_ key: String, _ error: Error) {
        progress[key] = nil
        self.error = "Download failed: \(error.localizedDescription)"
    }

    private func done(_ job: Job) async {
        do {
            let duration = try await AVURLAsset(url: dir.appending(path: job.file)).load(.duration).seconds
            try add(Download(video: job.id, kind: Kind(file: job.file), title: job.title, file: job.file, duration: duration, date: .now))
        } catch {
            fail(job.key, error)
        }
    }
}

enum DownloadError: LocalizedError {
    case status(Int)
    case missing(Kind)
    var errorDescription: String? {
        switch self {
        case .status(let code): "HTTP \(code)"
        case .missing(let kind): "No \(kind.label.lowercased()) file available for this video"
        }
    }
}

extension Downloads: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten written: Int64, totalBytesExpectedToWrite total: Int64) {
        guard total > 0 else { return }
        let key = Job(downloadTask).key
        Task { @MainActor in
            if self.progress[key] != nil { self.progress[key] = Double(written) / Double(total) }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let job = Job(downloadTask)
        let code = (downloadTask.response as! HTTPURLResponse).statusCode
        do {
            guard (200..<300).contains(code) else { throw DownloadError.status(code) }
            let dest = dir.appending(path: job.file)
            if FileManager.default.fileExists(atPath: dest.path(percentEncoded: false)) { try FileManager.default.removeItem(at: dest) }
            try FileManager.default.moveItem(at: location, to: dest)
            Task { @MainActor in await self.done(job) }
        } catch {
            Task { @MainActor in self.fail(job.key, error) }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let key = Job(task).key
        Task { @MainActor in self.fail(key, error) }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.finish?()
            self.finish = nil
        }
    }
}
