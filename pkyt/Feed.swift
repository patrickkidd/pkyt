import Foundation
import Observation

@MainActor
@Observable
final class Feed {
    let endpoint: Endpoint
    private(set) var videos: [Video] = []
    private(set) var next: String?
    private(set) var loading = false
    var error: String?
    @ObservationIgnored private let session: Session

    init(_ endpoint: Endpoint, session: Session) {
        self.endpoint = endpoint
        self.session = session
    }

    func load() async {
        videos = []
        next = nil
        await fetch(nil)
    }

    func more() async {
        guard let next, !loading else { return }
        await fetch(next)
    }

    private func fetch(_ token: String?) async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let page = try await session.client().page(endpoint, after: token)
            var seen = Set(videos.map(\.id))
            videos += page.videos.filter { seen.insert($0.id).inserted }
            next = page.next
        } catch is CancellationError {
        } catch let e as URLError where e.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
