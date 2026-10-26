import SwiftUI
import PhotosUI
import MajiangKit

/// 拍照：页面本身就是取景器，谁和了的四个名字浮在上面，按快门直接识别。
struct CaptureView: View {
    @Environment(AppModel.self) private var model
    @Bindable var flow: RoundFlow
    var close: () -> Void

    @State private var camera = CameraController()
    @State private var cameraOn = false
    @State private var choosingPhoto = false
    @State private var pickerItem: PhotosPickerItem?
    /// 端侧模型零点几秒就认完了，转圈晚一点出来，免得一闪而过。
    @State private var slow = false
    @State private var autoShot = false

    var body: some View {
        VStack(spacing: 0) {
            winnerPicker
                .padding(.top, 10)

            viewfinder
                .padding(.top, 20)

            Text(status ?? " ")
                .font(.system(size: 13))
                .foregroundStyle(flow.recognitionError == nil ? Color.white.opacity(0.72) : Color(hex: 0xF2A08F))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(minHeight: 34)
                .padding(.top, 10)

            controls
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(Theme.darkroom.ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("谁和了？")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.darkroom, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                .accessibilityLabel("关闭")
            }
        }
        .photosPicker(isPresented: $choosingPhoto, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    use(image)
                }
                pickerItem = nil
            }
        }
        // 核对页盖在上面时拍照页还在下面（定格的照片露在后面），相机先关掉
        .task(id: flow.steps.isEmpty) {
            guard flow.steps.isEmpty else {
                camera.stop()
                return
            }
            // 从核对页退回来时，照片清掉、还在跑的复核不要了，重新取景
            flow.cancelRecognition()
            flow.photo = nil
            cameraOn = await camera.start()
            await model.preloadOnDeviceModel()
            #if DEBUG
            // 截图用：`-demo-screen capture -auto-shoot` 进拍照页 1.5 秒后自动拍一张（演示数据），看核对页升上来、牌落下
            if model.demoScreen == .capture && ProcessInfo.processInfo.arguments.contains("-auto-shoot") && !autoShot {
                autoShot = true
                try? await Task.sleep(for: .seconds(1.5))
                use(UIImage(systemName: "photo") ?? UIImage())
            }
            #endif
        }
        .onDisappear { camera.stop() }
        .task(id: flow.isRecognizing) {
            slow = false
            guard flow.isRecognizing else { return }
            try? await Task.sleep(for: .seconds(0.6))
            if !Task.isCancelled { withAnimation(.easeIn(duration: 0.2)) { slow = true } }
        }
    }

    private var status: String? {
        if flow.isRecognizing { return slow ? "正在认牌…" : nil }
        return flow.recognitionError
    }

    private var winnerPicker: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                let on = flow.winner == i
                Button {
                    flow.winner = i
                } label: {
                    Text(flow.game.players[i].name)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(on ? Theme.ink : .white)
                        .background(on ? Color.white : Color.white.opacity(0.12), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .disabled(flow.isRecognizing)
    }

    private var viewfinder: some View {
        ZStack {
            if let photo = flow.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else if cameraOn {
                CameraPreview(session: camera.session)
            } else {
                // 没有相机（模拟器）或没给权限：画一手示意牌
                RadialGradient(colors: [Color(hex: 0x46443B), Color(hex: 0x2B2A25), Color(hex: 0x201F1B)],
                               center: UnitPoint(x: 0.5, y: 0.45), startRadius: 0, endRadius: 320)
                HStack(spacing: 2) {
                    ForEach(Array(Tile.parseList("11122334455667p").enumerated()), id: \.offset) { _, tile in
                        TileFace(tile: tile, width: 20, state: .dim)
                    }
                }
            }

            if flow.photo == nil {
                CornerBrackets()
                    .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .padding(22)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1.5)
                    .frame(height: 50)
                    .padding(.horizontal, 18)
                VStack {
                    Spacer()
                    Text(cameraOn || model.effectiveRecognitionMode == .demo ? "手牌推倒排成一排，和的那张放最右"
                         : "这台设备没有相机，从左下角的相册选一张")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 64)
                }
            }

            if flow.isRecognizing && slow {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .frame(width: 80, height: 80)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var controls: some View {
        ZStack {
            HStack {
                Button {
                    choosingPhoto = true
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .frame(width: 48, height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.3)))
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("从相册选")
                Spacer()
                Button("手动输入") { flow.startManualEntry() }
                    .buttonStyle(.text(.white.opacity(0.85)))
            }
            Button(action: shoot) {
                Circle()
                    .fill(.white)
                    .padding(7)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .frame(width: 76, height: 76)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("拍照")
        }
        .buttonStyle(.plain)
        .disabled(flow.isRecognizing)
        .opacity(flow.isRecognizing ? 0.4 : 1)
    }

    private func shoot() {
        if cameraOn {
            Task {
                if let image = await camera.capture() { use(image) }
            }
        } else if model.effectiveRecognitionMode == .demo {
            // 演示识别不看照片，模拟器里也能走完流程
            use(UIImage(systemName: "photo") ?? UIImage())
        } else {
            choosingPhoto = true
        }
    }

    private func use(_ image: UIImage) {
        flow.photo = image.downscaled()
        Task {
            await flow.recognize(with: model.makeRecognizer())
            // 认不出来时回到取景，让人重拍
            if flow.recognitionError != nil { flow.photo = nil }
        }
    }
}

/// 取景框四个角。
private struct CornerBrackets: Shape {
    var length: CGFloat = 26
    var radius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
        ]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * radius))
            path.addQuadCurve(to: CGPoint(x: corner.x + dx * radius, y: corner.y), control: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
        }
        return path
    }
}
