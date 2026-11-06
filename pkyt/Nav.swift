import Observation

@MainActor
@Observable
final class Nav {
    enum Tab: Hashable {
        case home
        case playlist
    }

    var tab = Tab.playlist
}
