import SwiftUI
import MajiangKit

/// 结果：从下往上弹出的一层。大番数、每个番种一句白话、这局谁付多少。
struct ResultSheet: View {
    var flow: RoundFlow
    var finish: (HandOutcome) -> Void
    /// 这一层有多高：矮屏（Duo 外屏、SE）大番数小一号，最后一句「谁付多少」不被底下的按钮切掉一半。
    @State private var pageHeight: CGFloat = 0
    private var short: Bool { pageHeight > 0 && pageHeight < Theme.shortPage }

    var body: some View {
        Group {
            if let record = flow.winRecord, let deltas = flow.deltas {
                content(record, deltas)
            } else {
                ContentUnavailableView("这手牌还和不了", systemImage: "exclamationmark.circle")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .presentationBackground(Theme.paper)
    }

    private func content(_ record: WinRecord, _ deltas: [Int]) -> some View {
        let game = flow.game
        let name = { (i: Int) in game.players[i].name }
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 谁和、怎么和的是记错最常见的地方：墨色写清楚，点一下收起结果回核对页改
                Button { flow.showResult = false } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(record.discarder.map { "\(name(record.winner)) · \(name($0))点炮" } ?? "\(name(record.winner)) · 自摸")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Text("改 ›")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.gray)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("回到核对页改谁和了、怎么和的")
                .padding(.top, short ? 8 : 20)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(record.totalFan)")
                        .font(.system(size: short ? 68 : 88, weight: .ultraLight).monospacedDigit())
                        .tracking(-2)
                    Text("番").font(Theme.serif(22))
                }
                .frame(maxWidth: .infinity)
                if game.rules.paidFan(record) < record.totalFan {
                    Text("家规封顶 \(game.rules.fanCap) 番：\(record.totalFan) 番按 \(game.rules.fanCap) 算")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.lineSoft, in: Capsule())
                        .frame(maxWidth: .infinity)
                }

                FanList(win: record)
                    .padding(.top, short ? 6 : 14)

                SectionLabel("这局谁付多少")
                    .padding(.top, short ? 16 : 22)
                    .padding(.bottom, 6)
                DeltaGrid(game: game, deltas: deltas)
                Text(game.paymentExplanation(record, deltas: deltas))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.gray)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
        }
        .bottomBar {
            Button("记下") { finish(.win(record)) }
                .buttonStyle(.primary)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
    }
}
