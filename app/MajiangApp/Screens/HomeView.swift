import SwiftUI
import MajiangKit

/// 首页：没打完的牌局、以前的牌局、开一局。有没打完的牌局时 App 直接打开牌桌，这里是返回后看到的。
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showGuide = false
    @State private var showSettings = false
    @State private var showBackup = false
    @State private var showInvite = false
    @State private var showMore = false
    @State private var showFeedback = false
    @State private var showLanguage = false
    /// 「更多」页里点了哪一项：等「更多」收下去再打开那一页，两层弹出不叠在一起。
    @State private var moreTarget: MoreTarget?

    private var isEmpty: Bool { model.archive.games.isEmpty }

    var body: some View {
        Group {
            if isEmpty {
                EmptyHome(more: moreMenu, openGuide: { showGuide = true }, openSettings: { showSettings = true },
                          openBackup: { showBackup = true }, start: { model.path.append(.newGame) })
            } else {
                list
            }
        }
        .page()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showGuide) { RulesGuideView().presentationCornerRadius(30) }
        .sheet(isPresented: $showBackup) { BackupView().presentationCornerRadius(30) }
        .sheet(isPresented: $showInvite) { InviteView().presentationCornerRadius(30) }
        .sheet(isPresented: $showFeedback) { FeedbackView().presentationCornerRadius(30) }
        .sheet(isPresented: $showLanguage) { LanguageSheet() }
        .sheet(isPresented: $showMore, onDismiss: openMoreTarget) {
            MoreSheet(items: moreItems) { target in
                moreTarget = target
                showMore = false
            }
        }
        .onAppear {
            if model.demoScreen == .backup { showBackup = true }
            if model.demoScreen == .invite { showInvite = true }
            if model.demoScreen == .more { showMore = true }
            if model.demoScreen == .language { showLanguage = true }
            if model.demoScreen == .feedback || model.demoScreen == .feedbackSent { showFeedback = true }
        }
        // 打完一场从结算页回来：等首页落定、返回的动画走完，再弹苹果的评分框
        .task(id: model.reviewPromptPending) {
            guard model.reviewPromptPending else { return }
            try? await Task.sleep(for: .seconds(model.demoScreen == .rate ? 1.2 : 0.8))
            guard !Task.isCancelled, model.reviewPromptPending else { return }
            ReviewPrompt.request()
            model.didAskForReview()
        }
        #if DEBUG
        .sheet(isPresented: $showSettings) { SettingsView().presentationCornerRadius(30) }
        #endif
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if let game = model.archive.activeGame {
                    SectionLabel("没打完")
                        .padding(.top, 44)
                        .padding(.bottom, 12)
                    Button {
                        model.path.append(.table(game.id))
                    } label: {
                        ActiveGameCard(game: game)
                    }
                    .buttonStyle(.plain)
                }

                if !model.archive.finishedGames.isEmpty {
                    SectionLabel("以前的")
                        .padding(.top, 36)
                        .padding(.bottom, 4)
                    ForEach(model.archive.finishedGames) { game in
                        Button {
                            model.path.append(.settle(game.id))
                        } label: {
                            HistoryRow(game: game)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error = model.loadError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
        .bottomBar {
            Button("开一局") { model.path.append(.newGame) }
                .buttonStyle(.primary)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "拍照算番")
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-0.5)
                    #if DEBUG
                    // 开发版的设置（识别方式、API Key）藏在长按标题里，正式版没有设置页
                    .onLongPressGesture { showSettings = true }
                    #endif
                Spacer()
                moreMenu
            }
            // 记过几手就不用再说 App 是干什么的
            if !model.isSeasoned {
                Text("打完一手，拍一下和牌的人的牌，App 帮你算番记账。")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 右上角的「更多」：灰字，点开从底下升起一页（App 自己的样式，不用系统菜单）。
    /// 第一次打开的空首页也有，审核员和新用户一打开就能找到填邀请码的地方。
    private var moreMenu: some View {
        Button { showMore = true } label: {
            Text("更多")
                .font(.system(size: 16))
                .foregroundStyle(Theme.gray)
                .fixedSize()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 「更多」里的几项。AI 认牌只在连我们服务器的版本里有（开发版直连 Google 时不出）。
    private var moreItems: [MoreSheet<MoreTarget>.Item] {
        var items: [MoreSheet<MoreTarget>.Item] = [
            .init(target: .guide, title: "番怎么算", detail: "国标的番种和收付，都是白话"),
            .init(target: .backup, title: "备份与换手机",
                  detail: model.cloud.enabled ? "iCloud 同步已打开" : "导出、导入牌局，或者打开 iCloud 同步"),
        ]
        if model.usesProxy || model.demoScreen == .invite || model.demoScreen == .more {
            let on = model.inviteCode != nil
            items.append(.init(target: .invite, title: on ? "AI 认牌 · 已开启" : "AI 认牌",
                               detail: on ? "看邀请码，或者移除" : "有邀请码就能开启，认牌更准"))
        }
        items.append(.init(target: .feedback, title: "提意见", detail: "哪里不好用、番算错了，直接告诉我们"))
        // 说明写现在的选择，用那种语言自己的写法（「English」「日本語」）
        items.append(.init(target: .language, title: "语言", detail: "\(AppLanguage.chosen.nativeName)"))
        return items
    }

    private func openMoreTarget() {
        switch moreTarget {
        case .guide: showGuide = true
        case .backup: showBackup = true
        case .invite: showInvite = true
        case .feedback: showFeedback = true
        case .language: showLanguage = true
        case nil: break
        }
        moreTarget = nil
    }
}

private enum MoreTarget {
    case guide, backup, invite, feedback, language
}

private struct ActiveGameCard: View {
    var game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(game.handLabel).font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("继续 ›").font(.system(size: 15)).foregroundStyle(Theme.gray)
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.players[i].name)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.gray)
                            .lineLimit(1)
                        Text(Theme.signed(game.scores[i]))
                            .font(Theme.score(24))
                            .foregroundStyle(Theme.scoreColor(game.scores[i]))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 20)
        .block(radius: 22)
        .contentShape(Rectangle())
    }
}

private struct HistoryRow: View {
    var game: Game

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.startedAt.dayLabel).font(.system(size: 16, weight: .medium))
                    Text("\(game.players.map(\.name).listText) · \(game.currentHandIndex) 局")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .lineLimit(1)
                }
                Spacer()
                // 自己这场的输赢，前面写上名字，不用猜是谁的分
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(game.players[game.me].name)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .lineLimit(1)
                    Text(Theme.signed(game.scores[game.me]))
                        .font(Theme.score(20))
                        .foregroundStyle(Theme.scoreColor(game.scores[game.me]))
                }
            }
            .padding(.vertical, 14)
            Hairline()
        }
        .contentShape(Rectangle())
    }
}

/// 第一次打开、还没有任何牌局时的首页：一句话加三步，说清这个 App 是干什么的。
private struct EmptyHome<More: View>: View {
    /// 右上角的「更多」菜单（跟有牌局时的首页同一个）。
    var more: More
    var openGuide: () -> Void
    var openSettings: () -> Void
    var openBackup: () -> Void
    var start: () -> Void

    var body: some View {
        GeometryReader { geo in
            // 安全区以下留 38，离屏幕顶约 100；SE、iPhone Duo 外屏这种矮屏只留 22，三步也排紧一点，免得第三步被按钮切掉
            let short = geo.size.height < 560
            let topInset: CGFloat = short ? 22 : 38
            ScrollView {
                // 品牌标在顶上；标题和步骤作为一块往下放，剩下的空白上 : 下 ≈ 5 : 3，两段都至少 32（矮屏 20）
                FiveThreeLayout(height: geo.size.height - topInset, minGap: short ? 20 : 32) {
                    HStack(alignment: .center) {
                        brand
                        Spacer()
                        more
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        headline
                        steps(rowPadding: short ? 14 : 24).padding(.top, short ? 24 : 40)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, topInset)
            }
        }
        .bottomBar {
            Button("开一局", action: start)
                .buttonStyle(.primary)
            Button("第一次打国标？先看看番怎么算", action: openGuide)
                .buttonStyle(.text(size: 14))
                .padding(.top, 10)
            // 新手机上没装 iCloud 同步时，从旧手机导出的文件导入
            Button("换了手机？导入以前的记录", action: openBackup)
                .buttonStyle(.text(size: 14))
        }
    }
}

private extension EmptyHome {
    var brand: some View {
        HStack(spacing: 12) {
            Text(verbatim: "和")
                .font(Theme.serif(17))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.vermilion, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(verbatim: "拍照算番").font(.system(size: 17, weight: .semibold))
        }
        .accessibilityElement(children: .combine)
        #if DEBUG
        // 开发版的设置（识别方式、API Key）藏在长按品牌标里，正式版没有设置页
        .onLongPressGesture { openSettings() }
        #endif
    }

    var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("拍一下，")
            Text("番和钱都算好。")
        }
        .font(Theme.serif(32, semibold: true))
    }

    func steps(rowPadding: CGFloat) -> some View {
        VStack(spacing: 0) {
            StepRow(number: "一", title: "拍", detail: "和牌的人把牌推倒，拍一张", padding: rowPadding) {
                HStack(spacing: 2) {
                    ForEach(Array(Tile.parseList("12355p").enumerated()), id: \.offset) { _, tile in
                        TileFace(tile: tile, width: 16)
                    }
                }
            }
            StepRow(number: "二", title: "算", detail: "认出牌，按国标算番", padding: rowPadding) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(verbatim: "32").font(Theme.score(30, weight: .ultraLight))
                    Text("番").font(Theme.serif(13, semibold: true))
                }
            }
            StepRow(number: "三", title: "记", detail: "谁给谁多少，自动记账", padding: rowPadding) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: "+120").foregroundStyle(Theme.vermilion)
                    Text(verbatim: "−40").foregroundStyle(Theme.ink)
                }
                .font(Theme.score(15))
            }
        }
    }
}

/// 两块竖排：第一块贴顶，第二块放在剩下的空白里，上方 : 下方 ≈ 5 : 3，两段都至少 `minGap`。
/// 屏幕太矮时整体比 `height` 高，外面的 ScrollView 可以滚。
private struct FiveThreeLayout: Layout {
    var height: CGFloat
    var minGap: CGFloat = 32

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let content = subviews.reduce(0) { $0 + $1.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        return CGSize(width: width, height: max(height, content + 2 * minGap))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let p = ProposedViewSize(width: bounds.width, height: nil)
        let top = subviews[0].sizeThatFits(p).height
        let block = subviews[1].sizeThatFits(p).height
        let free = bounds.height - top - block
        let below = max(minGap, free * 3 / 8)
        let above = max(minGap, free - below)
        subviews[0].place(at: bounds.origin, proposal: p)
        subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + top + above), proposal: p)
    }
}

/// 三步里的一行：朱红数字、标题和说明、右边一个小样。
private struct StepRow<Sample: View>: View {
    var number: LocalizedStringKey
    var title: LocalizedStringKey
    var detail: LocalizedStringKey
    /// 每行上下的留白，矮屏小一点。
    var padding: CGFloat = 24
    @ViewBuilder var sample: Sample

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 数字放进描边小方印，单独一笔的「一」才不像破折号
                Text(number)
                    .font(Theme.serif(15, semibold: true))
                    .foregroundStyle(Theme.vermilion)
                    .frame(width: 26, height: 26)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.vermilion, lineWidth: 1))
                    .frame(width: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 17, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.leading, 6)
                Spacer(minLength: 12)
                sample.accessibilityHidden(true)
            }
            .padding(.vertical, padding)
            Hairline()
        }
    }
}
