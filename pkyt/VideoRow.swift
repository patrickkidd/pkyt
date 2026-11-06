import SwiftUI

struct VideoRow: View {
    @Environment(Downloads.self) private var downloads
    @Environment(Player.self) private var player
    @Environment(Nav.self) private var nav
    @State private var saving = false
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: play) {
                VStack(alignment: .leading, spacing: 10) {
                    thumbnail
                    HStack(alignment: .top, spacing: 12) {
                        AsyncImage(url: video.avatar) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.night
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(video.byline)
                                .font(.caption)
                                .foregroundStyle(Color.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 36)
                    }
                }
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottomTrailing) {
                Button { saving.toggle() } label: {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(saving ? Color.pink : Color.cyan)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            if saving {
                HStack(spacing: 10) {
                    ForEach(Kind.allCases, id: \.self) { kind in
                        DownloadButton(video: video.id, title: video.title, kind: kind)
                    }
                }
            }
        }
        .padding(10)
        .card()
    }

    private var thumbnail: some View {
        AsyncImage(url: video.thumbnail) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Color.night
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .bottomTrailing) { badge.padding(6) }
    }

    @ViewBuilder private var badge: some View {
        if video.live {
            Label("LIVE", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.pink, in: RoundedRectangle(cornerRadius: 4))
        } else if let d = video.duration {
            Text(d)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private var icon: String {
        let states = Kind.allCases.map { downloads.state(video.id, $0) }
        if states.contains(where: { if case .active = $0 { true } else { false } }) { return "arrow.down.circle.dotted" }
        return states.contains(.done) ? "checkmark.circle.fill" : "arrow.down.circle"
    }

    private func play() {
        nav.tab = .playlist
        Task { await player.play(id: video.id) }
    }
}
