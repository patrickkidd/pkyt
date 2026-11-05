import AVFoundation
import Foundation
import Observation
import YouTubeKit

struct Download: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let file: String
    let duration: Double
    let date: Date
}

enum DownloadState: Equatable {
    case none
    case active(Double)
    case done
}

private struct Job: Codable {
    let id: String
    let title: String
    let file: String

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
                .sorted { $0.date > $1.date }
        }
        guard background else { return }
        session = URLSession(configuration: .background(withIdentifier: "com.patrickkidd.pkyt.downloads"), delegate: self, delegateQueue: nil)
        session.getAllTasks { tasks in
            let ids = tasks.filter { $0.state == .running }.map { Job($0).id }
            Task { @MainActor in
                for id in ids where self.progress[id] == nil { self.progress[id] = 0 }
            }
        }
    }

    private var index: URL { dir.appending(path: "index.json") }

    func url(_ item: Download) -> URL { dir.appending(path: item.file) }

    func state(_ id: String) -> DownloadState {
        if let p = progress[id] { return .active(p) }
        return items.contains { $0.id == id } ? .done : .none
    }

    func begin(_ id: String) -> Bool {
        guard state(id) == .none else { return false }
        progress[id] = 0
        error = nil
        return true
    }

    func start(_ video: YouTube, id: String, title: String) async {
        guard begin(id) else { return }
        do {
            guard let stream = Self.file(try await video.streams) else { throw PlayError.noStream }
            let job = Job(id: id, title: title, file: "\(id).\(stream.fileExtension.rawValue)")
            let task = session.downloadTask(with: stream.url)
            task.taskDescription = String(decoding: try JSONEncoder().encode(job), as: UTF8.self)
            task.resume()
        } catch {
            fail(id, error)
        }
    }

    func add(_ item: Download) throws {
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        progress[item.id] = nil
        try save()
    }

    func delete(_ item: Download) throws {
        try FileManager.default.removeItem(at: url(item))
        items.removeAll { $0.id == item.id }
        try save()
    }

    static func file(_ streams: [YouTubeKit.Stream]) -> YouTubeKit.Stream? {
        let s = streams.filter(\.isNativelyPlayable)
        return s.filterVideoAndAudio().highestResolutionStream() ?? s.filterAudioOnly().highestAudioBitrateStream()
    }

    private func save() throws {
        try JSONEncoder().encode(items).write(to: index, options: .atomic)
    }

    private func fail(_ id: String, _ error: Error) {
        progress[id] = nil
        self.error = "Download failed: \(error.localizedDescription)"
    }

    private func done(_ job: Job) async {
        do {
            let duration = try await AVURLAsset(url: dir.appending(path: job.file)).load(.duration).seconds
            try add(Download(id: job.id, title: job.title, file: job.file, duration: duration, date: .now))
        } catch {
            fail(job.id, error)
        }
    }
}

enum DownloadError: LocalizedError {
    case status(Int)
    var errorDescription: String? {
        switch self {
        case .status(let code): "HTTP \(code)"
        }
    }
}

extension Downloads: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten written: Int64, totalBytesExpectedToWrite total: Int64) {
        guard total > 0 else { return }
        let id = Job(downloadTask).id
        Task { @MainActor in
            if self.progress[id] != nil { self.progress[id] = Double(written) / Double(total) }
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
            Task { @MainActor in self.fail(job.id, error) }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let id = Job(task).id
        Task { @MainActor in self.fail(id, error) }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.finish?()
            self.finish = nil
        }
    }
}
