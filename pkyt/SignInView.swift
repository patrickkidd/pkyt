import SwiftUI
import WebKit

struct SignInView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Web(store: session.store) {
                Task {
                    await session.refresh()
                    if session.signedIn { dismiss() }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .background(.sky)
            .toolbarBackground(Color.night, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Sign in to YouTube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct Web: UIViewRepresentable {
    static let start = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://m.youtube.com/")!
    static let agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"

    let store: WKWebsiteDataStore
    let loaded: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(loaded) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = store
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = Self.agent
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: Self.start))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let loaded: () -> Void

        init(_ loaded: @escaping () -> Void) {
            self.loaded = loaded
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded()
        }
    }
}
