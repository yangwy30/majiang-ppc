import SwiftUI
import MajiangKit

/// 结果：从下往上弹出的一层。大番数、每个番种一句白话、这局谁付多少。
struct ResultSheet: View {
    @Environment(AppModel.self) private var model
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
                        Text(record.discarder.map { String(localized: "\(name(record.winner)) · \(name($0))点炮") } ?? String(localized: "\(name(record.winner)) · 自摸"))
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
            // AI 认错过、用户改对了：问一句要不要把照片发给我们。勾不勾都能记下，记住上一次的选择
            if flow.misreadCount > 0 {
                Toggle(isOn: Binding(get: { model.sharesMisreads }, set: { model.sharesMisreads = $0 })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("把照片发给我们，让 AI 认得更准")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink)
                        Text("AI 认错了 \(flow.misreadCount) 张，照片只用来改进认牌")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(CheckToggleStyle())
                .padding(.bottom, 12)
            }
            Button("记下") {
                if flow.misreadCount > 0, model.sharesMisreads, let photo = flow.photo, let recognized = flow.recognizedHand {
                    model.reportMisread(photo: photo, recognized: recognized, corrected: flow.correctedHand, source: flow.source)
                }
                finish(.win(record))
            }
            .buttonStyle(.primary)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
    }
}

/// 圆圈勾选：没勾是一圈浅灰，勾上是墨色实心圆里一个白勾。整行都能点。
struct CheckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(configuration.isOn ? Theme.ink : Theme.faint, lineWidth: 1.5)
                    if configuration.isOn {
                        Circle().fill(Theme.ink)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                .padding(.top, 1)
                configuration.label
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "已勾选" : "没勾选")
    }
}
