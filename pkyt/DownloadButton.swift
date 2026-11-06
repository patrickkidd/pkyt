import SwiftUI
import YouTubeKit

struct DownloadButton: View {
    @Environment(Downloads.self) private var downloads
    let video: String
    let title: String
    let kind: Kind
    var source: YouTube?

    var body: some View {
        let state = downloads.state(video, kind)
        Button {
            Task { await downloads.start(video, title: title, kind: kind, source: source) }
        } label: {
            HStack(spacing: 6) {
                switch state {
                case .none:
                    Image(systemName: "arrow.down.circle")
                    Text(kind.label)
                case .active(let p):
                    ProgressView().controlSize(.mini).tint(.cyan)
                    Text("\(kind.label) \(Int(p * 100))%").monospacedDigit()
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                    Text("\(kind.label) saved")
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(state == .done ? Color.muted : Color.cyan)
            .card()
        }
        .buttonStyle(.plain)
        .disabled(state != .none)
    }
}
