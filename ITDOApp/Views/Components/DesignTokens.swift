import SwiftUI

enum DesignTokens {
    static let background = Color(hex: "#000000")
    static let backgroundSecondary = Color(hex: "#222222")
    static let backgroundHover = Color(white: 1.0, opacity: 0.08)
    static let backgroundActive = Color(white: 1.0, opacity: 0.12)
    static let backgroundBlock = Color(hex: "#1C1C1C")
    static let backgroundModal = Color(hex: "#111111")
    static let backgroundGlass = Color(white: 1.0, opacity: 0.08)
    static let toolChipBg = Color(white: 1.0, opacity: 0.08)

    static let errorBg = Color(red: 0.937, green: 0.267, blue: 0.267, opacity: 0.12)
    static let errorBorder = Color(red: 0.937, green: 0.267, blue: 0.267, opacity: 0.30)

    static let textPrimary = Color(hex: "#f5f5f5")
    static let textSecondary = Color(white: 1.0, opacity: 0.5)
    static let textInverse = Color(hex: "#000000")

    static let accentPrimary = Color(hex: "#0080FF")
    static let accentSecondary = Color(hex: "#3b82f6")
    static let accentHover = Color(hex: "#93c5fd")
    static let accentLike = Color(hex: "#f91880")
    static let accentRepost = Color(hex: "#00ba7c")
    static let linkColor = Color(hex: "#6a9fd4")

    static let border = Color(white: 1.0, opacity: 0.15)
    static let borderSubtle = Color(white: 1.0, opacity: 0.05)

    static let error = Color(hex: "#ef4444")
    static let success = Color(hex: "#22c55e")

    static let agentGradient = LinearGradient(
        colors: [Color(hex: "#0080FF"), Color(hex: "#8b5cf6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let tabGradient = LinearGradient(
        colors: [DesignTokens.accentPrimary.opacity(0.45), DesignTokens.accentSecondary.opacity(0.32)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        let v = UInt64(h, radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
