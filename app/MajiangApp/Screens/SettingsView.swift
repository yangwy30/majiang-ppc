import SwiftUI
import MajiangKit

/// 开发版的设置（长按首页标题打开），正式版没有：选识别方式，填 Gemini API Key（开发用，存钥匙串）或后端代理地址（上架用）。
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var hasKey = GeminiKeychain.hasKey

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Picker("识别方式", selection: $model.recognitionMode) {
                        ForEach(RecognitionMode.allCases) { Text($0.title).tag($0) }
                    }
                } footer: {
                    Text("演示数据不看照片，按顺序给出三手示例牌。双读目前只有 Gemini 一路，端侧模型还没接入。")
                }

                Section {
                    SecureField(hasKey ? "已保存（重新填写可替换）" : "粘贴 API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("保存到钥匙串") {
                        GeminiKeychain.save(apiKey)
                        apiKey = ""
                        hasKey = GeminiKeychain.hasKey
                    }
                    .disabled(apiKey.isEmpty)
                    if hasKey {
                        Button("删除 Key", role: .destructive) {
                            GeminiKeychain.save("")
                            hasKey = false
                        }
                    }
                } header: {
                    Text("Gemini API Key")
                } footer: {
                    Text("只存在这台手机的钥匙串里，不会写进代码或上传。只用于开发测试；正式上架会改走我们自己的服务器，App 里不放 Key。")
                }

                Section {
                    TextField("https://…", text: $model.proxyURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("后端代理（可选）")
                } footer: {
                    Text("填了 https 地址后，识别请求发到这个地址，由服务器带上 Key 转发给 Gemini。")
                }
            }
            .page()
            .navigationTitle("开发设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("好") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}
