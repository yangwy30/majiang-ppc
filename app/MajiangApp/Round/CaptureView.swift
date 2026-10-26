import SwiftUI
import PhotosUI
import MajiangKit

/// 4. 拍照：先选谁和了，再拍和牌那家的牌。
struct CaptureView: View {
    @Environment(AppModel.self) private var model
    @Bindable var flow: RoundFlow
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(text: "谁和了")
                PlayerPicker(game: flow.game, selection: $flow.winner)

                viewfinder

                VStack(alignment: .leading, spacing: 6) {
                    hint("手牌推倒排一排，和的那张放最右", systemImage: "rectangle.split.3x1")
                    hint("吃碰杠放旁边，暗杠翻开一张", systemImage: "square.stack")
                    hint("正上方俯拍，牌占满画面，不要切边", systemImage: "viewfinder")
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)

                if let error = flow.recognitionError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.crimson)
                        .card(padding: 12)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if CameraPicker.isAvailable {
                    Button("拍照") { showCamera = true }
                        .buttonStyle(.primary)
                }
                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("从相册选")
                    }
                    .buttonStyle(.secondary)
                    Button("手动输入") { flow.startManualEntry() }
                        .buttonStyle(.secondary)
                }
            }
            .disabled(flow.isRecognizing)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Theme.canvas)
        }
        .page()
        .navigationTitle("记一局")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in use(image) }
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    use(image)
                }
                pickerItem = nil
            }
        }
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.ink.opacity(0.92))
            if let photo = flow.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius - 4, style: .continuous))
                    .padding(4)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera").font(.title)
                    Text("拍 \(flow.game.players[flow.winner].name) 的牌").font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.75))
            }
            if flow.isRecognizing {
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("正在认牌…").font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(20)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(height: 240)
    }

    /// 图标宽度不一，固定宽度让三行文字左边对齐。
    private func hint(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage).frame(width: 20)
        }
    }

    private func use(_ image: UIImage) {
        flow.photo = image.downscaled()
        Task { await flow.recognize(with: model.makeRecognizer()) }
    }
}
