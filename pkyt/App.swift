import SwiftUI

@main
struct PkytApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var player = Player()
    @State private var nav = Nav()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(player)
                .environment(Downloads.shared)
                .environment(nav)
                .preferredColorScheme(.dark)
                .fontDesign(.rounded)
                .tint(.pink)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        Downloads.shared.finish = completionHandler
    }
}
