import SwiftUI
import MajiangKit

/// 6. 怎么和的：自摸还是点炮、和的哪张、特殊情况、花牌。照片看不出来的都在这里补。
struct WinDetailsView: View {
    @Bindable var flow: RoundFlow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("和法", selection: $flow.selfDrawn) {
                    Text("自摸").tag(true)
                    Text("点炮").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: flow.selfDrawn) { _, selfDrawn in
                    if !selfDrawn && flow.discarder == nil { flow.discarder = flow.defaultDiscarder() }
                }

                if !flow.selfDrawn {
                    SectionTitle(text: "谁点的炮")
                    PlayerPicker(game: flow.game,
                                 selection: Binding(get: { flow.discarder ?? flow.defaultDiscarder() },
                                                    set: { flow.discarder = $0 }),
                                 excluded: flow.winner)
                }

                SectionTitle(text: "和的是哪张（影响边张、嵌张、单钓）")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(flow.tiles.enumerated()), id: \.element.id) { index, tile in
                            let selected = index == (flow.winningIndex ?? flow.tiles.count - 1)
                            Button {
                                flow.winningIndex = index
                            } label: {
                                TileFace(tile: tile.tile, width: 34)
                                    .offset(y: selected ? -6 : 0)
                                    .overlay(alignment: .bottom) {
                                        if selected {
                                            Capsule().fill(Theme.ink).frame(width: 16, height: 3).offset(y: 8)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 2)
                }
                .card(padding: 8)

                SectionTitle(text: "特殊情况")
                VStack(spacing: 0) {
                    ForEach(SpecialWin.allCases, id: \.self) { special in
                        let reason = special.unavailableReason(hand: flow.hand, selfDrawn: flow.selfDrawn)
                        Toggle(isOn: Binding(
                            get: { reason == nil && flow.specials.contains(special) },
                            set: { on in
                                if on {
                                    flow.specials.subtract(special.conflicts)
                                    flow.specials.insert(special)
                                } else {
                                    flow.specials.remove(special)
                                }
                            })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(special.name)
                                if let reason {
                                    Text(reason).font(.caption).foregroundStyle(Theme.tertiaryInk)
                                }
                            }
                        }
                        .disabled(reason != nil)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        if special != SpecialWin.allCases.last { Divider().overlay(Theme.border) }
                    }
                }
                .card(padding: 0)

                if flow.game.rules.includeFlowers {
                    Stepper(value: $flow.flowerCount, in: 0...8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("花牌 \(flow.flowerCount) 张")
                            Text("每张 1 番，不计入 8 番起和").font(.caption).foregroundStyle(Theme.secondaryInk)
                        }
                    }
                    .card()
                }

                HStack {
                    Text("圈风 \(flow.context.prevalentWind.name) · 门风 \(flow.context.seatWind.name)")
                    Spacer()
                    Text("按座位自动带出").foregroundStyle(Theme.tertiaryInk)
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                estimate
                Button("算番") { flow.steps.append(.result) }
                    .buttonStyle(.primary)
                    .disabled(flow.winRecord == nil)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Theme.canvas)
        }
        .page()
        .navigationTitle("怎么和的")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 和牌者可能在拍照页被改过，点炮者不能是和牌者本人
            if flow.discarder == flow.winner { flow.discarder = nil }
            if !flow.selfDrawn && flow.discarder == nil { flow.discarder = flow.defaultDiscarder() }
        }
    }

    @ViewBuilder
    private var estimate: some View {
        switch flow.scoring {
        case .success(let result):
            HStack {
                Text("预计").foregroundStyle(Theme.secondaryInk)
                Text("\(result.totalFan) 番").font(.headline.monospacedDigit())
                if result.flowerFan > 0 {
                    Text("（含花 \(result.flowerFan)）").font(.footnote).foregroundStyle(Theme.secondaryInk)
                }
                Spacer()
                if !result.meetsMinimum(flow.game.rules.minimumFan) {
                    Chip(text: "不够 \(flow.game.rules.minimumFan) 番", kind: .warning)
                }
            }
        case .failure(let error):
            Text(error.message).font(.footnote).foregroundStyle(Theme.crimson)
        }
    }
}
