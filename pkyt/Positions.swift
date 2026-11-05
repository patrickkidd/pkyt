import Foundation

struct Positions {
    private static let key = "positions"
    let defaults: UserDefaults

    init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var all: [String: Double] { defaults.dictionary(forKey: Self.key) as? [String: Double] ?? [:] }

    func start(_ id: String, link: Double?) -> Double {
        link ?? all[id] ?? 0
    }

    func save(_ id: String, at time: Double, duration: Double) {
        guard time >= 5 else { return }
        var all = all
        all[id] = duration.isFinite && duration - time < 10 ? nil : time
        defaults.set(all, forKey: Self.key)
    }
}
