import SwiftUI
import MajiangKit

/// 5. 确认牌面：两路识别不一致的牌用虚线框加「?」标出，点任意一张都可以改。
struct ConfirmTilesView: View {
    @Bindable var flow: RoundFlow
    @State private var editing: EditTarget?

    enum EditTarget: Identifiable {
        case tile(Int)
        case add
        case meld

        var id: String {
            switch self {
            case .tile(let i): "tile-\(i)"
            case .add: "add"
            case .meld: "meld"
            }
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusCard

                SectionTitle(text: "手牌（和的那张在最右）")
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(flow.tiles.enumerated()), id: \.element.id) { index, tile in
                        Button {
                            editing = .tile(index)
                        } label: {
                            TileCell(tile: tile, recommended: flow.recommended[index])
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        editing = .add
                    } label: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .overlay(Image(systemName: "plus").foregroundStyle(Theme.secondaryInk))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("加一张")
                }
                .card(padding: 12)

                HStack {
                    SectionTitle(text: "吃碰杠")
                    Button("加一组") { editing = .meld }
                        .font(.footnote.weight(.semibold))
                }
                if flow.melds.isEmpty {
                    Text("没有副露。照片里吃碰杠的分组如果没认出来，在这里补上。")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(flow.melds.enumerated()), id: \.offset) { index, meld in
                            HStack(spacing: 10) {
                                Text(meld.kindName).font(.subheadline.weight(.medium)).frame(width: 40, alignment: .leading)
                                TileRow(tiles: meld.tiles, width: 30)
                                Spacer()
                                Button {
                                    flow.melds.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.tertiaryInk)
                                }
                                .accessibilityLabel("删掉这组")
                            }
                            .padding(12)
                            if index < flow.melds.count - 1 { Divider().overlay(Theme.border) }
                        }
                    }
                    .card(padding: 0)
                }

                if !flow.source.isEmpty {
                    Text("识别：\(flow.source)").font(.caption).foregroundStyle(Theme.tertiaryInk)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if flow.isValidWin {
                    Button("下一步：怎么和的") { flow.steps.append(.details) }
                        .buttonStyle(.primary)
                } else {
                    Button("看看哪里不对") { flow.steps.append(.notWin) }
                        .buttonStyle(.primary)
                        .disabled(flow.tiles.isEmpty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Theme.canvas)
        }
        .page()
        .navigationTitle("确认牌面")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { target in
            sheet(for: target)
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if flow.pendingReviewCount > 0 {
                    Chip(text: "\(flow.pendingReviewCount) 张需要确认", kind: .warning)
                } else if flow.isValidWin {
                    Chip(text: "牌型成立", kind: .success)
                } else {
                    Chip(text: "还不成和", kind: .warning)
                }
                Spacer()
                Text("\(flow.hand.allTiles.count) 张").font(.footnote).foregroundStyle(Theme.secondaryInk)
            }
            // 成和时标签已经写了「牌型成立」，不再重复一遍
            if flow.pendingReviewCount > 0 || !flow.isValidWin {
                Text(WinAssistant.explain(flow.hand, context: flow.context, minimumFan: flow.game.rules.minimumFan))
                    .font(.subheadline)
            }
            ForEach(flow.notes, id: \.self) { note in
                Text(note).font(.footnote).foregroundStyle(Theme.amber)
            }
            if !flow.recommended.isEmpty {
                Button("按规则推荐的读法全部确认") { flow.acceptRecommendations() }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .card()
    }

    @ViewBuilder
    private func sheet(for target: EditTarget) -> some View {
        switch target {
        case .tile(let index) where flow.tiles.indices.contains(index):
            let tile = flow.tiles[index]
            TileEditSheet(title: "第 \(index + 1) 张", current: tile.tile, candidates: tile.candidates,
                          recommended: flow.recommended[index],
                          onPick: { flow.choose($0, at: index); flow.recommended[index] = nil },
                          onDelete: { flow.remove(at: index); flow.recommended = [:] })
        case .add:
            TileEditSheet(title: "加一张", current: nil, onPick: { flow.append($0) })
        case .meld:
            MeldEditSheet { flow.melds.append($0) }
        default:
            EmptyView()
        }
    }
}

/// 一张待确认的牌：需要确认的用琥珀色虚线框加「?」。
private struct TileCell: View {
    var tile: RecognizedTile
    var recommended: Tile?

    var body: some View {
        VStack(spacing: 3) {
            TileFace(tile: tile.tile, width: 40)
                .overlay {
                    if tile.needsReview {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Theme.amber, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            .padding(-3)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if tile.needsReview {
                        Text("?")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Theme.amber, in: Circle())
                            .offset(x: 6, y: -6)
                    }
                }
            if let recommended, tile.needsReview {
                Text(recommended == tile.tile ? "能和" : "→\(recommended.displayName)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.green)
                    .lineLimit(1)
            }
        }
    }
}
