import SwiftUI

extension Color {
    static let night = Color(red: 0x1B / 255, green: 0x17 / 255, blue: 0x40 / 255)
    static let ink = Color(red: 0x0B / 255, green: 0x0A / 255, blue: 0x1A / 255)
    static let surface = Color(red: 0x2A / 255, green: 0x24 / 255, blue: 0x5E / 255)
    static let pink = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0xA2 / 255)
    static let cyan = Color(red: 0x7B / 255, green: 0xE3 / 255, blue: 0xFF / 255)
    static let sun = Color(red: 0xFF / 255, green: 0xD5 / 255, blue: 0x4A / 255)
    static let muted = Color.white.opacity(0.6)
}

extension ShapeStyle where Self == LinearGradient {
    static var sky: LinearGradient {
        LinearGradient(colors: [.night, .ink], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    func card() -> some View {
        background(Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
