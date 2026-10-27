import SwiftUI
import MajiangKit

/// 开局：按出牌顺序填四个名字，第一个是第一局的庄。规则收成一行，一般设一次就不再改；
/// 填的 4 个人以前一起打过，就自动用上次那场的家规。
struct NewGameView: View {
    @Environment(AppModel.self) private var model
    @State private var names = ["", "", "", ""]
    @State private var rules = GameRules()
    @State private var editingRules = false
    /// 规则是按这 4 个人上次那场自动带上的。
    @State private var rulesFromGroup = false
    /// 自己点开改过规则，就不再按名字自动换。
    @State private var rulesTouched = false
    @FocusState private var focused: Int?

    private var trimmed: [String] { names.map { $0.trimmingCharacters(in: .whitespaces) } }

    private var canStart: Bool {
        trimmed.allSatisfy { !$0.isEmpty } && Set(trimmed).count == 4
    }

    /// 不能开始时按钮上直接写原因。
    private var startLabel: String {
        if canStart { return "开始" }
        let filled = trimmed.filter { !$0.isEmpty }
        return Set(filled).count < filled.count ? "名字不能重复" : "填好 4 个名字"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(title: "谁在打？", subtitle: "从第一局的庄家开始，按出牌顺序填。")

                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        HStack(spacing: 14) {
                            Text(Wind(rawValue: i)!.name)
                                .font(Theme.serif(15))
                                .foregroundStyle(Theme.faint)
                                .frame(width: 22, alignment: .leading)
                            TextField("名字", text: $names[i])
                                .font(.system(size: 17))
                                .focused($focused, equals: i)
                                .submitLabel(i < 3 ? .next : .done)
                                .onSubmit { focused = i < 3 ? i + 1 : nil }
                                .accessibilityLabel("第 \(i + 1) 位")
                            if i == 0 { DealerStamp() }
                        }
                        .frame(height: 58)
                        if i < 3 { Hairline(color: Theme.lineSoft) }
                    }
                }
                .block(radius: 22)
                .padding(.top, 28)

                if !frequentNames.isEmpty {
                    SectionLabel("常一起打的")
                        .padding(.top, 28)
                        .padding(.bottom, 10)
                    FlowLayout(spacing: 8) {
                        ForEach(frequentNames, id: \.self) { name in
                            NameChip(name: name, selected: false) { add(name) }
                        }
                    }
                }

                Button {
                    editingRules = true
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("规则").font(.system(size: 16))
                            Spacer()
                            Text(rules.shortSummary + " ›")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.gray)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        if rulesFromGroup {
                            Text("上次跟这 4 位就这么打的")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.gray)
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(minHeight: 56)
                    .block(radius: 18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .bottomBar {
            Button(startLabel) { start() }
            .buttonStyle(.primary)
            .disabled(!canStart)
        }
        .page()
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { model.path.removeLast() }
                    .buttonStyle(.text(size: 17))
            }
        }
        .sheet(isPresented: $editingRules) {
            RulesSheet(rules: $rules, opening: model.demoScreen == .rulePicker ? .cap : nil)
        }
        .onAppear {
            rules = model.archive.lastRules
            if model.demoScreen == .houseRules || model.demoScreen == .rulePicker {
                rules.fanCap = 64
                rules.yuanPerPoint = 2
                editingRules = true
            }
        }
        .onChange(of: trimmed) { _, names in
            guard !rulesTouched else { return }
            if let remembered = model.archive.lastRules(forPlayers: names) {
                rules = remembered
                rulesFromGroup = true
            } else if rulesFromGroup {
                rules = model.archive.lastRules
                rulesFromGroup = false
            }
        }
        .onChange(of: rules) {
            if editingRules {
                rulesTouched = true
                rulesFromGroup = false
            }
        }
    }

    private var frequentNames: [String] {
        model.archive.frequentPlayers.map(\.name).filter { !trimmed.contains($0) }
    }

    /// 点一下常一起打的人，按顺序填进第一个空位。
    private func add(_ name: String) {
        if let i = trimmed.firstIndex(where: \.isEmpty) {
            names[i] = name
        }
    }

    private func start() {
        let known = Dictionary(model.archive.frequentPlayers.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let players = trimmed.map { known[$0] ?? Player(name: $0) }
        let game = model.startGame(players: players, rules: rules)
        model.path = [.table(game.id)]
    }
}

/// 规则：家规表单，开局时改。
private struct RulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var rules: GameRules
    /// 截图用：一打开就点开这一项。
    var opening: RuleItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                HouseRulesForm(rules: $rules, opening: opening)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
            }
            .page()
            .navigationTitle("规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("好") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

/// 自动换行的横排（常用牌友标签用）。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
