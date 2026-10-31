import SwiftUI
import MajiangKit

/// AI 认牌的邀请码：填码开启，或者看已经填的码、移除。码对不对由中转站说了算。
/// 没码也能正常用：拍照后用离线认牌，读错的点一下改；也可以手动选牌。
struct InviteView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if let code = model.inviteCode {
                    Section {
                        LabeledContent("邀请码") {
                            Text(code).font(.system(size: 17, weight: .medium, design: .monospaced)).tracking(2)
                        }
                        Text("AI 认牌已开启")
                            .foregroundStyle(Theme.gray)
                    } footer: {
                        Text("拍照后先出离线认牌的结果，AI 再认一遍，两边读得不一样的牌让你选。")
                    }
                    Section {
                        Button("移除邀请码", role: .destructive) { model.removeInvite() }
                    }
                } else {
                    Section {
                        TextField("6 位邀请码", text: $input)
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .tracking(3)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit(redeem)
                            .onChange(of: input) { error = nil }
                        Button(action: redeem) {
                            HStack {
                                Text("开启 AI 认牌")
                                if busy {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(busy || InviteCode.normalize(input) == nil)
                        if let message = error ?? model.inviteNotice {
                            Text(message)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.vermilion)
                        }
                    } footer: {
                        Text("AI 认牌用云端大模型读牌，比手机上的离线认牌准。现在是邀请制，朋友给了你邀请码就填在这里。\n\n没有邀请码也能正常用：拍照后先用离线认牌，读错的牌点一下改，也可以手动选牌。算番、记账都一样。")
                    }
                }
            }
            .page()
            .navigationTitle("AI 认牌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavClose("关闭") { dismiss() }
            }
            .onAppear { if model.inviteCode == nil { focused = true } }
        }
    }

    private func redeem() {
        guard !busy, InviteCode.normalize(input) != nil else { return }
        busy = true
        Task {
            error = await model.redeemInvite(input)
            busy = false
            if error == nil { input = "" }
        }
    }
}
