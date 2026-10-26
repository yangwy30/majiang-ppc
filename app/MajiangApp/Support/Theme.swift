import SwiftUI
import UIKit

/// 视觉「墨与朱」：纸白底、墨色字，整个 App 只用一种朱红（庄的印章、赢的分数）。
/// 输的分数用墨色加负号，不用红绿。
enum Theme {
    static let paper = Color(hex: 0xF7F6F2)
    static let white = Color.white
    static let line = Color(hex: 0xE7E4DC)
    /// 白色块里面的分隔线。
    static let lineSoft = Color(hex: 0xEFECE6)
    static let gray = Color(hex: 0x6E6C64)
    static let faint = Color(hex: 0xA8A59C)
    static let ink = Color(hex: 0x16150F)
    static let vermilion = Color(hex: 0xC23B22)
    static let segment = Color(hex: 0xECEAE3)
    /// 拍照页的底色。
    static let darkroom = Color(hex: 0x0F0F0D)

    // 牌面
    static let tileFace = Color(hex: 0xFFFDF8)
    static let tileDim = Color(hex: 0xE9E5DA)
    static let tileEdge = Color(hex: 0xE2DDD0)
    static let tileShadow = Color(hex: 0xD6D0C1)
    static let tileBlue = Color(hex: 0x23406B)
    static let tileGreen = Color(hex: 0x2F5D46)
    static let tileRed = Color(hex: 0xC23B22)

    static func scoreColor(_ value: Int) -> Color { value > 0 ? vermilion : ink }

    /// 「+92」「−76」「0」。负号用真正的减号，和加号一样宽。
    static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : value < 0 ? "−\(-value)" : "0"
    }

    /// 分数：SF 细体，等宽数字。
    static func score(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    /// 宋体只用于风位、庄和「番」字。系统没有宋体时退回衬线体。
    static func serif(_ size: CGFloat) -> Font {
        if let name = songti { return .custom(name, fixedSize: size) }
        return .system(size: size, weight: .semibold, design: .serif)
    }

    private static let songti: String? = ["STSongti-SC-Bold", "STSongti-SC-Regular"]
        .first { UIFont(name: $0, size: 12) != nil }
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

extension View {
    /// 纸白底的页面。
    func page() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
    }

    /// 白色圆角块：只用来收纳一组设置，列表不套卡片。
    func block(radius: CGFloat = 20) -> some View {
        self
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.white, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// 页面底部固定的按钮区，底下垫一层纸色，免得滚动内容透出来。
    func bottomBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        safeAreaInset(edge: .bottom) {
            VStack(spacing: 4, content: content)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Theme.paper)
        }
    }
}

/// 每页唯一的黑色胶囊主按钮。不能点时变成灰底，按钮上直接写原因。
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isEnabled ? 17 : 16, weight: isEnabled ? .semibold : .medium))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(isEnabled ? Color.white : Theme.gray)
            .background(isEnabled ? Theme.ink.opacity(configuration.isPressed ? 0.82 : 1) : Theme.line, in: Capsule())
            .contentShape(Capsule())
    }
}

/// 其余操作都是文字按钮，没有描边按钮。
struct TextButtonStyle: ButtonStyle {
    var color: Color = Theme.gray
    var size: CGFloat = 15

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size))
            .foregroundStyle(color)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == TextButtonStyle {
    static var text: TextButtonStyle { TextButtonStyle() }
    static func text(_ color: Color = Theme.gray, size: CGFloat = 15) -> TextButtonStyle {
        TextButtonStyle(color: color, size: size)
    }
}

/// 朱红印章「庄」。
struct DealerStamp: View {
    var size: CGFloat = 22

    var body: some View {
        Text("庄")
            .font(Theme.serif(size * 0.6))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.vermilion, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityLabel("庄家")
    }
}

/// 灰色小节标题，比如「账本」「常一起打的」。
struct SectionLabel: View {
    var text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 页面大标题和一行灰色说明。
struct PageTitle: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.4)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 两段的切换：底色 #ECEAE3，选中的一段是白色。
struct SegmentedSwitch<Value: Hashable>: View {
    var options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, label in
                let on = value == selection
                Button {
                    selection = value
                } label: {
                    Text(label)
                        .font(.system(size: 15, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Theme.ink : Theme.gray)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.white)
                                    .shadow(color: Theme.ink.opacity(0.08), radius: 1.5, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.segment, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

/// 选人的胶囊：选中黑底白字，没选白底细线。
struct NameChip: View {
    var name: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 15))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .background(selected ? Theme.ink : Theme.white, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.line))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 细线。
struct Hairline: View {
    var color: Color = Theme.line

    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}
