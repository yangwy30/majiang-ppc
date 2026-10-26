import SwiftUI
import MajiangKit

/// 34 种牌的选择面板：万、条、饼各一行，字牌一行。
struct TilePickerGrid: View {
    var selected: Tile?
    var onPick: (Tile) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 9)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([Suit.characters, .bamboo, .dots, .honors], id: \.self) { suit in
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Tile.all.filter { $0.suit == suit }, id: \.self) { tile in
                        Button {
                            onPick(tile)
                        } label: {
                            TileFace(tile: tile, width: 34)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Theme.ink, lineWidth: tile == selected ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// 改一张牌：先给出两路识别的候选，下面是全部牌。
struct TileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var current: Tile?
    var candidates: [Tile] = []
    var recommended: Tile?
    var onPick: (Tile) -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if candidates.count > 1 {
                        SectionTitle(text: "两次识别读得不一样，是哪张？")
                        HStack(spacing: 16) {
                            ForEach(candidates, id: \.self) { tile in
                                Button {
                                    pick(tile)
                                } label: {
                                    VStack(spacing: 6) {
                                        TileFace(tile: tile, width: 64)
                                        Text(tile.displayName).font(.subheadline.weight(.medium))
                                        if tile == recommended {
                                            Chip(text: "这张才能和", kind: .success)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .card()
                    }
                    SectionTitle(text: candidates.count > 1 ? "都不是？从这里选" : "选一张")
                    TilePickerGrid(selected: current) { pick($0) }
                        .card(padding: 12)
                    if let onDelete {
                        Button("删掉这张", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .buttonStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .page()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func pick(_ tile: Tile) {
        onPick(tile)
        dismiss()
    }
}

/// 加一组吃、碰、杠。
struct MeldEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (Meld) -> Void

    enum Kind: String, CaseIterable, Identifiable {
        case chow = "吃", pung = "碰", kong = "明杠", concealedKong = "暗杠"
        var id: String { rawValue }
    }

    @State private var kind = Kind.pung

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("类型", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    SectionTitle(text: kind == .chow ? "选顺子最小的那张（567饼 选 5饼）" : "选是哪张牌")
                    TilePickerGrid(selected: nil) { tile in
                        if let meld = makeMeld(tile) {
                            onAdd(meld)
                            dismiss()
                        }
                    }
                    .card(padding: 12)
                }
                .padding(20)
            }
            .page()
            .navigationTitle("加一组副露")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func makeMeld(_ tile: Tile) -> Meld? {
        switch kind {
        case .chow: return Meld.chow(tile)
        case .pung: return Meld.pung(tile)
        case .kong: return Meld.kong(tile, concealed: false)
        case .concealedKong: return Meld.kong(tile, concealed: true)
        }
    }
}
