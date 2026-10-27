import SwiftUI
import MajiangKit

/// 家规：一行一项，左边名字和一句白话，右边大数字。跟国标一样的值是灰色细体，改过的是墨色，
/// 不用别的标记就看得出改了哪几项。点一行从底下弹出几个常用值来选。
/// 开局页和牌桌上「这场的规则」都用它。
struct HouseRulesForm: View {
    @Binding var rules: GameRules
    /// 已经打了几局：中途改规则时，圈数不能少于这个。
    var playedHands = 0
    /// 截图用：一打开就点开这一项。
    var opening: RuleItem?

    @State private var picking: RuleItem?
    @State private var showMore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PresetTabs(rules: $rules)

            VStack(spacing: 0) {
                ForEach(RuleItem.main) { item in
                    RuleRow(item: item, rules: rules, large: true) { picking = item }
                }
            }
            .padding(.top, 4)

            Text(example)
                .font(.system(size: 13))
                .foregroundStyle(Theme.gray)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Button {
                withAnimation(.easeOut(duration: 0.2)) { showMore.toggle() }
            } label: {
                HStack {
                    Text(moreLabel)
                    Spacer()
                    Text(showMore ? "收起" : "›")
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.text(size: 14))
            .padding(.top, 14)

            if showMore {
                VStack(spacing: 0) {
                    Hairline()
                    ForEach(RuleItem.more) { item in
                        RuleRow(item: item, rules: rules, large: false) { picking = item }
                    }
                }
            }
        }
        .sheet(item: $picking) { item in
            RulePicker(item: item, rules: $rules, playedHands: playedHands)
        }
        .onAppear {
            // 「更多」里有改过的就直接展开，免得藏着
            showMore = RuleItem.more.contains { !$0.isStandard(rules) }
            if let opening { picking = opening }
        }
    }

    private var moreLabel: String {
        let changed = RuleItem.more.filter { !$0.isStandard(rules) }.count
        return changed > 0 ? "更多规矩 · 改过 \(changed) 项" : "更多规矩"
    }

    /// 「比如自摸 24 番：三家各付 32 分，一共赢 192 元。」随改随算。
    private var example: String {
        let fan = rules.cappedFan(24)
        let each = rules.basePoints + fan
        let money = (Double(each * 3) * rules.yuanPerPoint).formatted(.number.precision(.fractionLength(0...2)))
        return "比如自摸 24 番：三家各付 \(each) 分，一共赢 \(money) 元。"
    }
}

// MARK: - 预设

/// 「标准国标」「新手局」，改过就多出一个「自己定」。换预设不动 1 分几元。
private struct PresetTabs: View {
    @Binding var rules: GameRules

    private var current: Int {
        rules.scoresLike(.standard) ? 0 : rules.scoresLike(.beginner) ? 1 : 2
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 22) {
                tab("标准国标", index: 0, preset: .standard)
                tab("新手局", index: 1, preset: .beginner)
                if current == 2 { tab("自己定", index: 2, preset: nil) }
                Spacer()
            }
            Hairline()
        }
        .animation(.easeOut(duration: 0.15), value: current)
    }

    private func tab(_ label: String, index: Int, preset: GameRules?) -> some View {
        let on = current == index
        return Button {
            guard var preset else { return }
            preset.yuanPerPoint = rules.yuanPerPoint
            rules = preset
        } label: {
            Text(label)
                .font(.system(size: 15, weight: on ? .medium : .regular))
                .foregroundStyle(on ? Theme.ink : Theme.faint)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(on ? Theme.ink : .clear).frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - 一行

private struct RuleRow: View {
    var item: RuleItem
    var rules: GameRules
    /// 常用的 5 项用大数字；「更多」里的用普通字号。
    var large: Bool
    var action: () -> Void

    var body: some View {
        let value = item.value(rules)
        // 跟国标一样：灰色、更细；改过：墨色。灰色要在牌桌灯下也看得清，不用更淡的 faint
        let standard = item.isStandard(rules)
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.system(size: 16))
                        if large {
                            Text(item.hint)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.gray)
                        }
                    }
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value.text)
                            .font(large ? .system(size: value.isNumber ? 34 : 20, weight: standard ? .thin : .light)
                                    .monospacedDigit()
                                  : .system(size: 16, weight: standard ? .regular : .medium))
                        if !value.unit.isEmpty {
                            Text(value.unit).font(.system(size: 14))
                        }
                    }
                    .foregroundStyle(standard ? Theme.gray : Theme.ink)
                }
                .frame(minHeight: large ? 84 : 56)
                Hairline()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("点一下改")
    }
}

// MARK: - 选项

/// 从底下弹出来的选项：几个常用值，标着哪个是国标。
private struct RulePicker: View {
    @Environment(\.dismiss) private var dismiss
    var item: RuleItem
    @Binding var rules: GameRules
    var playedHands: Int
    @State private var customYuan = ""

    var body: some View {
        let options = item.options(playedHands: playedHands, current: rules)
        VStack(alignment: .leading, spacing: 0) {
            Text(item.title)
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 30)
            Text(item.note)
                .font(.system(size: 13))
                .foregroundStyle(Theme.gray)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 10)

            ForEach(options) { option in
                let selected = option.isSelected(rules)
                Button {
                    option.apply(&rules)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Text(option.label)
                            .font(.system(size: 17, weight: selected ? .semibold : .regular))
                        Spacer()
                        if let tag = option.tag {
                            Text(tag).font(.system(size: 13)).foregroundStyle(Theme.gray)
                        }
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .opacity(selected ? 1 : 0)
                    }
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!option.enabled)
                .opacity(option.enabled ? 1 : 0.35)
                .accessibilityAddTraits(selected ? .isSelected : [])
                Hairline(color: Theme.lineSoft)
            }

            if item == .rate {
                HStack {
                    Text("其他").font(.system(size: 17))
                    Spacer()
                    TextField("填一个数", text: $customYuan)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text("元").foregroundStyle(Theme.gray)
                }
                .frame(height: 52)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(Theme.ink)
        .presentationDetents([.height(height(options.count))])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.white)
        .onChange(of: customYuan) { _, text in
            if let value = Double(text.replacingOccurrences(of: ",", with: ".")), value > 0 {
                rules.yuanPerPoint = value
            }
        }
    }

    private func height(_ count: Int) -> CGFloat {
        CGFloat(110 + (count + (item == .rate ? 1 : 0)) * 53)
    }
}

// MARK: - 规则项

/// 规则里能改的一项：名字、白话、显示的值、几个常用选项。
enum RuleItem: String, Identifiable, CaseIterable {
    case rate, base, minimum, cap, flowers
    case discarder, penalty, rounds, swap

    var id: String { rawValue }

    static let main: [RuleItem] = [.rate, .base, .minimum, .cap, .flowers]
    static let more: [RuleItem] = [.discarder, .penalty, .rounds, .swap]

    var title: String {
        switch self {
        case .rate: "1 分算"
        case .base: "底分"
        case .minimum: "起和"
        case .cap: "封顶"
        case .flowers: "花牌"
        case .discarder: "点炮谁付"
        case .penalty: "错和赔每家"
        case .rounds: "打几圈"
        case .swap: "每圈换座"
        }
    }

    /// 行里名字下面那句。
    var hint: String {
        switch self {
        case .rate: "「打一块的」就是 1 元"
        case .base: "有人和了，三家先各付"
        case .minimum: "凑够几番才能和"
        case .cap: "一把最多算几番"
        case .flowers: "每张花 1 番，不算进起和"
        case .discarder, .penalty, .rounds, .swap: ""
        }
    }

    /// 选项页上的说明。
    var note: String {
        switch self {
        case .rate: "每桌自己定，换预设不会动这一项。"
        case .base: "有人和了，另外三家先各付这么多，再按番数付。"
        case .minimum: "国标要凑够 8 番才能和。刚学的凑不够，可以降下来；1 番就是和了就算。"
        case .cap: "怕一把输太多就封顶：番数超过这个数，按这个数收钱。"
        case .flowers: "带花时，和牌前摸到的每张花算 1 番，不算进起和。"
        case .discarder: "国标：点炮的人付底分加番数，另外两家也各付底分。有的桌只让点炮的人付。"
        case .penalty: "推倒了却凑不成和牌，赔另外三家各这么多，这一局接着打。"
        case .rounds: "一圈 4 局。没打完也可以随时结束。"
        case .swap: "比赛每圈换一次座，朋友局一般不换。"
        }
    }

    func isStandard(_ rules: GameRules) -> Bool {
        let standard = GameRules.standard
        switch self {
        case .rate: return rules.yuanPerPoint == standard.yuanPerPoint
        case .base: return rules.basePoints == standard.basePoints
        case .minimum: return rules.minimumFan == standard.minimumFan
        case .cap: return rules.fanCap == standard.fanCap
        case .flowers: return rules.includeFlowers == standard.includeFlowers
        case .discarder: return rules.onlyDiscarderPays == standard.onlyDiscarderPays
        case .penalty: return rules.falseWinPenalty == standard.falseWinPenalty
        case .rounds: return rules.totalHands == standard.totalHands
        case .swap: return rules.swapSeatsEachRound == standard.swapSeatsEachRound
        }
    }

    /// 行右边的值：数字加单位，或者一个词。
    func value(_ rules: GameRules) -> (text: String, unit: String, isNumber: Bool) {
        switch self {
        case .rate: (rules.yuanPerPoint.yuanText, "元", true)
        case .base: ("\(rules.basePoints)", "分", true)
        case .minimum: ("\(rules.minimumFan)", "番", true)
        case .cap: rules.fanCap > 0 ? ("\(rules.fanCap)", "番", true) : ("不封顶", "", false)
        case .flowers: (rules.includeFlowers ? "带花" : "不带", "", false)
        case .discarder: (rules.onlyDiscarderPays ? "只有点炮的人" : "三家都付底分", "", false)
        case .penalty: ("\(rules.falseWinPenalty) 分", "", false)
        case .rounds: ("\(rules.totalHands / 4) 圈", "", false)
        case .swap: (rules.swapSeatsEachRound ? "换" : "不换", "", false)
        }
    }

    func options(playedHands: Int, current: GameRules) -> [RuleOption] {
        switch self {
        case .rate:
            var values = [0.5, 1, 2, 5, 10]
            if !values.contains(current.yuanPerPoint) { values.append(current.yuanPerPoint); values.sort() }
            return values.map { RuleOption.choice(\.yuanPerPoint, $0, "\($0.yuanText) 元", marksStandard: false) }
        case .base:
            var values = [0, 5, 8, 10]
            if !values.contains(current.basePoints) { values.append(current.basePoints); values.sort() }
            return values.map { RuleOption.choice(\.basePoints, $0, "\($0) 分", tag: $0 == 0 ? "不要底分" : nil) }
        case .minimum:
            return [8, 6, 4, 1].map { RuleOption.choice(\.minimumFan, $0, "\($0) 番", tag: $0 == 1 ? "和了就算" : nil) }
        case .cap:
            return [0, 88, 64, 32].map { RuleOption.choice(\.fanCap, $0, $0 == 0 ? "不封顶" : "\($0) 番") }
        case .flowers:
            return [true, false].map { RuleOption.choice(\.includeFlowers, $0, $0 ? "带花" : "不带花") }
        case .discarder:
            return [false, true].map { RuleOption.choice(\.onlyDiscarderPays, $0, $0 ? "只有点炮的人付" : "三家都付底分") }
        case .penalty:
            var values = [10, 5, 20]
            if !values.contains(current.falseWinPenalty) { values.append(current.falseWinPenalty) }
            return values.map { RuleOption.choice(\.falseWinPenalty, $0, "\($0) 分") }
        case .rounds:
            // 已经打了的局数之内的圈数不能选
            return [16, 8, 4].map { hands in
                var option = RuleOption.choice(\.totalHands, hands, "\(hands / 4) 圈")
                option.enabled = hands >= playedHands
                return option
            }
        case .swap:
            return [false, true].map { RuleOption.choice(\.swapSeatsEachRound, $0, $0 ? "换座" : "不换") }
        }
    }
}

struct RuleOption: Identifiable {
    var label: String
    var tag: String?
    var isSelected: (GameRules) -> Bool
    var apply: (inout GameRules) -> Void
    var enabled = true

    var id: String { label }

    /// 选一个值；跟国标一样的值标「国标」，其余的用 `tag`（1 分几元不标国标）。
    static func choice<T: Equatable>(_ keyPath: WritableKeyPath<GameRules, T>, _ value: T, _ label: String,
                                     tag: String? = nil, marksStandard: Bool = true) -> RuleOption {
        let isStandard = marksStandard && GameRules.standard[keyPath: keyPath] == value
        return RuleOption(label: label, tag: isStandard ? "国标" : tag,
                          isSelected: { $0[keyPath: keyPath] == value },
                          apply: { $0[keyPath: keyPath] = value })
    }
}

extension Double {
    /// 「2」「0.5」：1 分几元的写法。
    var yuanText: String { formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) }
}
