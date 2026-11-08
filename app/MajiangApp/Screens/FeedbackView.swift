import SwiftUI
import MajiangKit

/// 提意见：一段话，可以留个联系方式，发到中转站（Yang 在 /admin 上看）。
/// 样子跟填邀请码页一样：大标题、白块，底部一个黑色主按钮，不能点时按钮上写原因。
/// 发出去以后同一页换成「收到了」，把用户写的话原样摆出来，让人放心真的发到了。
struct FeedbackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var text = ""
    @State private var contact = ""
    @State private var busy = false
    @State private var error: String?
    @State private var sent = false
    @FocusState private var focus: Field?

    private enum Field { case text, contact }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmed.isEmpty && !busy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if sent { thanks } else { form }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .animation(.easeOut(duration: 0.25), value: sent)
            }
            .scrollDismissesKeyboard(.interactively)
            .page()
            .bottomBar {
                if sent {
                    Button("好") { dismiss() }
                        .buttonStyle(.primary)
                } else {
                    Button(busy ? "正在发…" : trimmed.isEmpty ? "写几个字再发" : "发送", action: send)
                        .buttonStyle(.primary)
                        .disabled(!canSend)
                }
                // 打字时键盘顶上来，收起这行，好让联系方式和下面那句说明露出来
                if sent || focus == nil {
                    Button(sent ? "顺手去 App Store 打个分" : "觉得好用？去 App Store 打个分") {
                        openURL(ReviewPrompt.writeReviewURL)
                    }
                    .buttonStyle(.text(size: 14))
                }
            }
            .sensoryFeedback(.success, trigger: sent) { _, new in new }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 发完了也留着「关闭」：跟填邀请码页一样，导航栏在，标题的位置就不跳
                NavClose(sent || trimmed.isEmpty ? "关闭" : "取消") { dismiss() }
            }
            .onAppear {
                #if DEBUG
                if model.demoScreen == .feedback || model.demoScreen == .feedbackSent {
                    text = String(localized: "杠上开花没算出来：最后一张是杠完补的牌，结果只给了自摸。", bundle: .ui)
                    contact = "yang_mj"
                }
                if model.demoScreen == .feedbackSent { sent = true }
                #endif
                if !sent { focus = .text }
            }
        }
    }

    // MARK: 写

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "提意见", subtitle: "哪里不好用、想要什么，都可以说。")

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("比如：杠上开花没算出来")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.faint)
                        .padding(.top, 16)
                        .padding(.leading, 18)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 17))
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: .text)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .frame(minHeight: 136)
                    .disabled(busy)
                    .onChange(of: text) { _, new in
                        if new.count > FeedbackClient.maxTextLength { text = String(new.prefix(FeedbackClient.maxTextLength)) }
                        error = nil
                    }
                    .accessibilityLabel("想说的话")
            }
            .background(Theme.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(focus == .text ? Theme.ink : Theme.line, lineWidth: focus == .text ? 1.5 : 1)
            }
            .contentShape(Rectangle())
            .onTapGesture { focus = .text }
            .padding(.top, 24)

            TextField("", text: $contact, prompt: Text("微信号或邮箱，想要回复再填").foregroundStyle(Theme.faint))
                .font(.system(size: 17))
                .focused($focus, equals: .contact)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .onSubmit(send)
                .disabled(busy)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Theme.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(focus == .contact ? Theme.ink : Theme.line, lineWidth: focus == .contact ? 1.5 : 1)
                }
                .onChange(of: contact) { _, new in
                    if new.count > FeedbackClient.maxContactLength { contact = String(new.prefix(FeedbackClient.maxContactLength)) }
                }
                .accessibilityLabel("联系方式，可以不填")
                .padding(.top, 12)

            Text(error ?? String(localized: "只带 App 版本和手机型号，不带照片和牌局。", bundle: .ui))
                .font(.system(size: 13))
                .foregroundStyle(error == nil ? Theme.gray : Theme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
    }

    // MARK: 发完

    private var thanks: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "收到了，谢谢",
                      subtitle: contact.isEmpty ? "每一条都会看，改好了会写在更新说明里。" : "每一条都会看。改好了会联系你。")

            VStack(alignment: .leading, spacing: 10) {
                Text(trimmed)
                    .font(.system(size: 16))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                if !contact.isEmpty {
                    Text("联系方式：\(contact)")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                }
            }
            .padding(.vertical, 18)
            .block()
            .padding(.top, 28)
        }
        .transition(.opacity)
    }

    private func send() {
        guard canSend else { return }
        busy = true
        focus = nil
        Task {
            error = await model.sendFeedback(text: trimmed, contact: contact)
            busy = false
            if error == nil {
                sent = true
            } else {
                focus = .text
            }
        }
    }
}
