import AVKit
import SwiftUI

struct ContentView: View {
    @State private var player = Player()
    @State private var downloads = Downloads.shared
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
                .overlay(alignment: .trailing) {
                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 6)
                    }
                }
            Button("Paste & Play") { paste(force: true) }
                .buttonStyle(.borderedProminent)
            if player.loading {
                ProgressView("Loading…")
            }
            if let title = player.title {
                Text(title).font(.headline)
            }
            VideoPlayer(player: player.av)
                .aspectRatio(16 / 9, contentMode: .fit)
            if let error = player.error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
            if let id = player.id {
                download(id)
            }
            if let error = downloads.error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
            List {
                ForEach(downloads.items) { item in
                    Button { player.play(item, at: downloads.url(item)) } label: {
                        HStack {
                            Text(item.title).lineLimit(2)
                            Spacer()
                            Text(Self.time(item.duration)).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
                .onDelete { offsets in
                    for item in offsets.map({ downloads.items[$0] }) { delete(item) }
                }
            }
            .listStyle(.plain)
        }
        .padding()
        .onChange(of: phase) { _, new in
            if new == .active { paste(force: false) }
            if new == .background { player.save() }
        }
        .onOpenURL { url in
            if let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value {
                play(target)
            }
        }
    }

    @ViewBuilder
    private func download(_ id: String) -> some View {
        switch downloads.state(id) {
        case .none:
            Button("Download") {
                guard let video = player.video else { return }
                Task { await downloads.start(video, id: id, title: player.title ?? id) }
            }
            .buttonStyle(.bordered)
            .disabled(player.video == nil)
        case .active(let p):
            Button("Downloading \(Int(p * 100))%") {}
                .buttonStyle(.bordered)
                .disabled(true)
        case .done:
            Button("Downloaded") {}
                .buttonStyle(.bordered)
                .disabled(true)
        }
    }

    private func delete(_ item: Download) {
        if player.file == downloads.url(item) { player.stop() }
        do {
            try downloads.delete(item)
        } catch {
            downloads.error = "Delete failed: \(error.localizedDescription)"
        }
    }

    private static func time(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
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
