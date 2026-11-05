import AVKit
import SwiftUI

struct ContentView: View {
    @State private var player = Player()
    @State private var text = ""
    @State private var pasteCount = UIPasteboard.general.changeCount
    @Environment(\.scenePhase) private var phase

    var body: some View {
        VStack(spacing: 12) {
            TextField("YouTube URL", text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { play(text) }
            Button("Paste & Play") { paste(force: true) }
                .buttonStyle(.borderedProminent)
            if let title = player.title {
                Text(title).font(.headline)
            }
            VideoPlayer(player: player.av)
                .aspectRatio(16 / 9, contentMode: .fit)
            if let error = player.error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
            Spacer()
        }
        .padding()
        .onChange(of: phase) { _, new in
            if new == .active { paste(force: false) }
        }
        .onOpenURL { url in
            if let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value {
                play(target)
            }
        }
    }

    private func paste(force: Bool) {
        let board = UIPasteboard.general
        guard force || board.changeCount != pasteCount else { return }
        pasteCount = board.changeCount
        guard board.hasStrings, let s = board.string else { return }
        if force || (Link(s) != nil && s != player.last) { play(s) }
    }

    private func play(_ s: String) {
        text = s
        Task { await player.play(s) }
    }
}
