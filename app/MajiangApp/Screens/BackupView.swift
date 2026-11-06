import SwiftUI
import UniformTypeIdentifiers
import MajiangKit

/// 备份与换手机：iCloud 同步开关，加上不用 iCloud 时的导出 / 导入文件。
struct BackupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        @Bindable var cloud = model.cloud
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageTitle(title: "备份与换手机", subtitle: "换了新手机，以前的牌局也跟着走。")

                    Hairline()
                        .padding(.top, 28)
                    MenuRow(title: "iCloud 同步", detail: statusLine.map { (line: String) -> LocalizedStringKey in "\(line)" } ?? "存在你自己的 iCloud 里，别人看不到",
                            detailLines: nil) {
                        Toggle("iCloud 同步", isOn: $cloud.enabled)
                            .labelsHidden()
                            .tint(Theme.ink)
                    }
                    note("换新手机时登录同一个 Apple ID，打开 App 记录就都回来了；iPad 上装了也会同步。")

                    SectionLabel("不用 iCloud")
                        .padding(.top, 36)
                        .padding(.bottom, 2)
                    Hairline()
                    Button { export() } label: {
                        MenuRow(title: "导出全部牌局", detail: "存成一个文件，放到「文件」里或者隔空投送", detailLines: nil) { chevron }
                    }
                    .buttonStyle(.plain)
                    Button { importing = true } label: {
                        MenuRow(title: "从文件导入", detail: "在新手机上选导出的那个文件", detailLines: nil) { chevron }
                    }
                    .buttonStyle(.plain)
                    note("导入只会添加和更新，不会删掉这台手机上已有的牌局。")
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .page()
            .onChange(of: cloud.enabled) { _, on in
                if on { Task { await model.syncNow() } }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavClose("关闭") { dismiss() }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): importFile(url)
                case .failure(let error): message = String(localized: "没有导入：\(error.localizedDescription)")
                }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好") { message = nil }
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.faint)
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Theme.gray)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
    }

    private var statusLine: String? {
        switch model.cloud.status {
        case .off: nil
        case .unavailable(let reason), .failed(let reason): reason
        case .syncing: String(localized: "正在同步…")
        case .synced(let date): String(localized: "已同步 · \(date.formatted(date: .omitted, time: .shortened))")
        }
    }

    private func export() {
        do {
            ShareSheet.present([try model.exportFile()])
        } catch {
            message = String(localized: "导出失败：\(error.localizedDescription)")
        }
    }

    private func importFile(_ url: URL) {
        do {
            let summary = try model.importFile(url)
            let parts = [summary.added > 0 ? String(localized: "加了 \(summary.added) 场牌局") : nil,
                         summary.updated > 0 ? String(localized: "更新了 \(summary.updated) 场") : nil]
            message = summary.isEmpty ? String(localized: "文件里的牌局这台手机上都有了。")
                : String(localized: "\(parts.compactMap { $0 }.joined(separator: Money.clauseSeparator))。")
        } catch {
            message = String(localized: "这个文件读不出来，确认是「导出全部牌局」导出的文件。")
        }
    }
}
