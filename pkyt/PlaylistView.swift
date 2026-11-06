import AVKit
import SwiftUI

struct PlaylistView: View {
    @Environment(Player.self) private var player
    @Environment(Downloads.self) private var downloads
    @State private var text = ""
    @State private var pasteCount = UIPasteboard.general.changeCount
    @Environment(\.scenePhase) private var phase

    var body: some View {
        VStack(spacing: 14) {
            field
            if player.loading {
                ProgressView().tint(.cyan)
            }
            if let title = player.title {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            screen
            if let error = player.error {
                Text(error).foregroundStyle(Color.pink).font(.footnote)
            }
            if let id = player.id {
                HStack(spacing: 10) {
                    ForEach(Kind.allCases, id: \.self) { kind in
                        DownloadButton(video: id, title: player.title ?? id, kind: kind, source: player.video)
                    }
                }
            }
            if let error = downloads.error {
                Text(error).foregroundStyle(Color.pink).font(.footnote)
            }
            list
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.sky)
        .onChange(of: phase) { _, new in
            if new == .active { paste(force: false) }
            if new == .background { player.save() }
        }
        .onChange(of: player.last) { _, new in
            if let new { text = new }
        }
        .onOpenURL { url in
            if let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value {
                play(target)
            }
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            HStack {
                Image(systemName: "link").foregroundStyle(Color.muted)
                TextField("YouTube URL", text: $text)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { play(text) }
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.muted)
                    }
                }
            }
            .padding(12)
            .card()
            Button { paste(force: true) } label: {
                Label("Paste & Play", systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.pink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var screen: some View {
        if player.id == nil && !player.loading {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.surface)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform").font(.largeTitle).foregroundStyle(Color.cyan)
                        Text("Paste a link or pick from your list").font(.footnote).foregroundStyle(Color.muted)
                    }
                }
        } else {
            VideoPlayer(player: player.av) {
                if let item = player.item, item.kind == .audio {
                    AsyncImage(url: item.thumbnail) { $0.resizable().scaledToFit() } placeholder: { Color.ink }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var list: some View {
        List {
            ForEach(downloads.items) { item in
                Button { player.play(item) } label: {
                    Row(item: item, playing: player.item?.id == item.id)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
            }
            .onMove { from, to in
                do {
                    try downloads.move(from: from, to: to)
                } catch {
                    downloads.error = "Reorder failed: \(error.localizedDescription)"
                }
            }
            .onDelete { offsets in
                for item in offsets.map({ downloads.items[$0] }) { delete(item) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if downloads.items.isEmpty {
                Text("Downloads appear here").font(.footnote).foregroundStyle(Color.muted)
            }
        }
    }

    private func delete(_ item: Download) {
        if player.item?.id == item.id { player.stop() }
        do {
            try downloads.delete(item)
        } catch {
            downloads.error = "Delete failed: \(error.localizedDescription)"
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
