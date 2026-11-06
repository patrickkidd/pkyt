import SwiftUI

struct Row: View {
    let item: Download
    let playing: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.thumbnail) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: item.kind.symbol).foregroundStyle(Color.muted)
            }
            .frame(width: 96, height: 54)
            .background(Color.ink)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Text(Self.time(item.duration))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 4)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(playing ? Color.pink : .white)
                    .lineLimit(2)
                Badge(kind: item.kind)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .card()
    }

    static func time(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}
