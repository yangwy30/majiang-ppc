import SwiftUI

/// 视觉沿用 bway-lot：暖白底、白卡片细边框、墨黑文字和主按钮，酒红只用于庄和输分。
enum Theme {
    static let canvas = Color(hex: 0xFAF9F5)
    static let card = Color.white
    static let border = Color(hex: 0xE6E4DD)
    static let ink = Color(hex: 0x141413)
    static let secondaryInk = Color(hex: 0x6B6A64)
    static let tertiaryInk = Color(hex: 0xA3A19A)
    static let crimson = Color(hex: 0x9E2A47)
    static let green = Color(hex: 0x1D6344)
    static let greenSoft = Color(hex: 0xEAF5EF)
    static let amber = Color(hex: 0x8F5B14)
    static let amberSoft = Color(hex: 0xFEF6E6)
    static let crimsonSoft = Color(hex: 0xF8ECEF)

    // 牌面
    static let tileFace = Color(hex: 0xFFFEFB)
    static let tileDots = Color(hex: 0x1F4E79)
    static let tileBamboo = Color(hex: 0x1D6344)
    static let tileRed = Color(hex: 0xB0263B)

    static let radius: CGFloat = 14

    /// 分数颜色：赢绿、输酒红、零灰。
    static func scoreColor(_ value: Int) -> Color {
        value > 0 ? green : value < 0 ? crimson : secondaryInk
    }

    static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - 通用组件

/// 白卡片，1px 细边框。
struct CardBackground: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardBackground(padding: padding)) }

    /// 暖白底的页面。
    func page() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
    }
}

/// 实心黑色主按钮。
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(Theme.ink.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.3),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 白底细边框次按钮。
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(Theme.ink)
            .background(configuration.isPressed ? Theme.border.opacity(0.4) : Theme.card,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// 状态小标签：绿色成功、琥珀需确认、酒红庄。
struct Chip: View {
    enum Kind { case success, warning, dealer, neutral }
    var text: String
    var kind: Kind = .neutral

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch kind {
        case .success: Theme.green
        case .warning: Theme.amber
        case .dealer: Theme.crimson
        case .neutral: Theme.secondaryInk
        }
    }

    private var background: Color {
        switch kind {
        case .success: Theme.greenSoft
        case .warning: Theme.amberSoft
        case .dealer: Theme.crimsonSoft
        case .neutral: Theme.border.opacity(0.5)
        }
    }
}

/// 页面里的小节标题。
struct SectionTitle: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
