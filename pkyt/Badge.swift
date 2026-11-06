import SwiftUI

struct Badge: View {
    let kind: Kind

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.symbol)
            Text(kind.label.uppercased())
        }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.cyan)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.cyan.opacity(0.15), in: Capsule())
    }
}
