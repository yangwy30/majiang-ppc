import SwiftUI
import MajiangKit

/// 2. 新建牌局：四个座位 + 规则。
struct NewGameView: View {
    @Environment(AppModel.self) private var model
    @State private var names = ["", "", "", ""]
    @State private var rules = GameRules()
    @State private var yuanText = "1"
    @FocusState private var focused: Int?

    private var canStart: Bool {
        names.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            && Set(names.map { $0.trimmingCharacters(in: .whitespaces) }).count == 4
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(text: "座位（东家是第一局的庄）")
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        HStack(spacing: 12) {
                            Text(Wind(rawValue: i)!.name)
                                .font(.headline)
                                .frame(width: 28, height: 28)
                                .background(i == 0 ? Theme.crimsonSoft : Theme.canvas, in: Circle())
                                .foregroundStyle(i == 0 ? Theme.crimson : Theme.ink)
                            TextField(i == 0 ? "你的名字" : "名字", text: $names[i])
                                .focused($focused, equals: i)
                                .submitLabel(i < 3 ? .next : .done)
                                .onSubmit { focused = i < 3 ? i + 1 : nil }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        if i < 3 { Divider().overlay(Theme.border) }
                    }
                }
                .card(padding: 0)

                HStack {
                    Button {
                        names.shuffle()
                    } label: {
                        Label("随机座位", systemImage: "shuffle")
                    }
                    .buttonStyle(.secondary)
                }

                if !frequentNames.isEmpty {
                    SectionTitle(text: "常用牌友")
                    FlowLayout(spacing: 8) {
                        ForEach(frequentNames, id: \.self) { name in
                            Button(name) { add(name) }
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Theme.card, in: Capsule())
                                .overlay(Capsule().stroke(Theme.border))
                                .buttonStyle(.plain)
                        }
                    }
                }

                SectionTitle(text: "规则")
                VStack(spacing: 0) {
                    HStack {
                        Text("1 分折合")
                        Spacer()
                        TextField("1", text: $yuanText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("元").foregroundStyle(Theme.secondaryInk)
                    }
                    .padding(16)
                    Divider().overlay(Theme.border)
                    HStack {
                        Text("底分 \(rules.basePoints) · \(rules.minimumFan) 番起和")
                        Spacer()
                        Text("国标固定").foregroundStyle(Theme.secondaryInk)
                    }
                    .padding(16)
                    Divider().overlay(Theme.border)
                    Toggle("带花牌", isOn: $rules.includeFlowers).padding(16)
                    Divider().overlay(Theme.border)
                    Toggle(isOn: $rules.swapSeatsEachRound) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("每圈换座")
                            Text("比赛规则；朋友局一般不换").font(.footnote).foregroundStyle(Theme.secondaryInk)
                        }
                    }
                    .padding(16)
                }
                .card(padding: 0)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button("开始") { start() }
                .buttonStyle(.primary)
                .disabled(!canStart)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Theme.canvas)
        }
        .page()
        .navigationTitle("新建牌局")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rules = model.archive.lastRules
            yuanText = rules.yuanPerPoint.formatted()
        }
    }

    private var frequentNames: [String] {
        model.archive.frequentPlayers.map(\.name).filter { !names.contains($0) }
    }

    private func add(_ name: String) {
        if let i = names.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            names[i] = name
        }
    }

    private func start() {
        rules.yuanPerPoint = Double(yuanText.replacingOccurrences(of: ",", with: ".")) ?? 1
        let known = Dictionary(model.archive.frequentPlayers.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let players = names.map { raw -> Player in
            let name = raw.trimmingCharacters(in: .whitespaces)
            return known[name] ?? Player(name: name)
        }
        let game = model.startGame(players: players, rules: rules)
        model.path = [.table(game.id)]
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
