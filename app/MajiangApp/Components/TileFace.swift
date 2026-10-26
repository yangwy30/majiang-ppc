import SwiftUI
import MajiangKit

/// 扁平真牌（风格 A）：饼画圆点，条画竹节，万写数字配红色「萬」，没有立体厚度。
/// 用在要对照桌上真牌的地方：确认牌面、选和张、不成和页。小尺寸和明细里用 `TileText`。
struct TileFace: View {
    var tile: Tile
    var width: CGFloat = 44

    private var height: CGFloat { width * 4 / 3 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(Theme.tileFace)
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
            face
                .frame(width: width * 0.8, height: height * 0.84)
        }
        .frame(width: width, height: height)
        .accessibilityElement()
        .accessibilityLabel(tile.displayName)
    }

    @ViewBuilder
    private var face: some View {
        switch tile.suit {
        case .dots: DotsFace(rank: tile.rank)
        case .bamboo: BambooFace(rank: tile.rank)
        case .characters: CharacterFace(rank: tile.rank, width: width)
        case .honors: HonorFace(tile: tile, width: width)
        }
    }
}

/// 图案里的一个点，单位坐标（0–1）。
private struct Spot {
    var x: CGFloat
    var y: CGFloat
    var red = false
}

private func spot(_ x: CGFloat, _ y: CGFloat, red: Bool = false) -> Spot { Spot(x: x, y: y, red: red) }

/// 网格排列；`red` 决定哪些点画成红色。
private func grid(_ xs: [CGFloat], _ ys: [CGFloat], red: (CGFloat, CGFloat) -> Bool = { _, _ in false }) -> [Spot] {
    var spots: [Spot] = []
    for y in ys {
        for x in xs { spots.append(Spot(x: x, y: y, red: red(x, y))) }
    }
    return spots
}

/// 在单位坐标里摆放图案。
private struct Pattern<Content: View>: View {
    var points: [Spot]
    var mark: (Bool) -> Content

    var body: some View {
        GeometryReader { geo in
            ForEach(points.indices, id: \.self) { i in
                mark(points[i].red)
                    .position(x: points[i].x * geo.size.width, y: points[i].y * geo.size.height)
            }
        }
    }
}

private struct DotsFace: View {
    var rank: Int

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height) * diameter
            Pattern(points: Self.layout(rank)) { red in
                ZStack {
                    Circle().fill(red ? Theme.tileRed : Theme.tileDots)
                    Circle().fill(Theme.tileFace).padding(d * 0.28)
                    Circle().fill(red ? Theme.tileRed : Theme.tileDots).padding(d * 0.4)
                }
                .frame(width: d, height: d)
            }
        }
    }

    private var diameter: CGFloat {
        switch rank {
        case 1: 0.8
        case 2, 3: 0.42
        case 4, 5: 0.4
        default: 0.3
        }
    }

    static func layout(_ rank: Int) -> [Spot] {
        switch rank {
        case 1: return [spot(0.5, 0.5, red: true)]
        case 2: return [spot(0.5, 0.27), spot(0.5, 0.73)]
        case 3: return [spot(0.22, 0.2), spot(0.5, 0.5, red: true), spot(0.78, 0.8)]
        case 4: return grid([0.28, 0.72], [0.27, 0.73])
        case 5: return grid([0.26, 0.74], [0.22, 0.78]) + [spot(0.5, 0.5, red: true)]
        case 6: return grid([0.3, 0.7], [0.17]) + grid([0.3, 0.7], [0.55, 0.84], red: { _, _ in true })
        case 7: return [spot(0.2, 0.12), spot(0.5, 0.24), spot(0.8, 0.36)]
            + grid([0.3, 0.7], [0.6, 0.86], red: { _, _ in true })
        case 8: return grid([0.3, 0.7], [0.12, 0.37, 0.63, 0.88])
        default: return grid([0.2, 0.5, 0.8], [0.17, 0.5, 0.83], red: { _, y in y == 0.5 })
        }
    }
}

private struct BambooFace: View {
    var rank: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * (rank == 8 ? 0.13 : 0.15)
            let h = geo.size.height * (rank >= 7 ? 0.26 : 0.36)
            if rank == 1 {
                // 幺鸡：画成一根带红顶的大竹节，和桌上的鸟一眼对得上
                VStack(spacing: geo.size.height * 0.04) {
                    Circle().fill(Theme.tileRed).frame(width: geo.size.width * 0.3)
                    Stick(red: false).frame(width: geo.size.width * 0.22, height: geo.size.height * 0.62)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            } else {
                Pattern(points: Self.layout(rank)) { red in
                    Stick(red: red).frame(width: w, height: h)
                }
            }
        }
    }

    static func layout(_ rank: Int) -> [Spot] {
        switch rank {
        case 2: return [spot(0.5, 0.27), spot(0.5, 0.73)]
        case 3: return [spot(0.5, 0.27), spot(0.28, 0.73), spot(0.72, 0.73)]
        case 4: return grid([0.28, 0.72], [0.27, 0.73])
        case 5: return grid([0.2, 0.8], [0.27, 0.73]) + [spot(0.5, 0.5, red: true)]
        case 6: return grid([0.2, 0.5, 0.8], [0.27, 0.73])
        case 7: return [spot(0.5, 0.15, red: true)] + grid([0.2, 0.5, 0.8], [0.5, 0.84])
        case 8: return grid([0.14, 0.38, 0.62, 0.86], [0.27, 0.73])
        default: return grid([0.2, 0.5, 0.8], [0.15, 0.5, 0.85], red: { x, _ in x == 0.5 })
        }
    }
}

/// 一节竹子：圆角竖条，中间一道节。
private struct Stick: View {
    var red: Bool

    var body: some View {
        GeometryReader { geo in
            let color = red ? Theme.tileRed : Theme.tileBamboo
            ZStack {
                Capsule().fill(color)
                Rectangle().fill(Theme.tileFace).frame(height: max(1, geo.size.height * 0.07))
            }
        }
    }
}

private struct CharacterFace: View {
    var rank: Int
    var width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Text(Tile(suit: .characters, rank: rank)!.faceCharacter)
                .font(.system(size: width * 0.42, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("萬")
                .font(.system(size: width * 0.44, weight: .bold))
                .foregroundStyle(Theme.tileRed)
        }
        .minimumScaleFactor(0.5)
    }
}

private struct HonorFace: View {
    var tile: Tile
    var width: CGFloat

    var body: some View {
        if tile.rank == 7 {
            // 白板：蓝色细框
            RoundedRectangle(cornerRadius: width * 0.08)
                .stroke(Theme.tileDots, lineWidth: max(1.5, width * 0.05))
                .padding(width * 0.06)
        } else {
            Text(tile.faceCharacter)
                .font(.system(size: width * 0.62, weight: .heavy))
                .foregroundStyle(color)
                .minimumScaleFactor(0.5)
        }
    }

    private var color: Color {
        switch tile.rank {
        case 5: Theme.tileRed
        case 6: Theme.tileBamboo
        default: Theme.ink
        }
    }
}

/// 文字牌（风格 B）：「567饼」「3万」，用颜色区分花色。用在账本、历史、番种明细和小尺寸。
struct TileText: View {
    var tiles: [Tile]
    var font: Font = .body

    var body: some View {
        Text(tiles.displayText)
            .font(font.monospacedDigit())
    }
}

/// 一排扁平真牌，副露之间留空。
struct TileRow: View {
    var tiles: [Tile]
    var width: CGFloat = 36

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                TileFace(tile: tile, width: width)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([Suit.characters, .bamboo, .dots, .honors], id: \.self) { suit in
                TileRow(tiles: Tile.all.filter { $0.suit == suit }, width: 36)
            }
        }
        .padding()
    }
    .page()
}
