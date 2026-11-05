import AppKit
import CoreText

// 产品页截图：纸白底、墨色宋体标题、一点朱红，下面放模拟器截图。
// 用法：swift frame.swift <font.ttf> <shots dir> <out dir> [宽x高]
//   宽x高：成图尺寸，默认 1320x2868（6.9 寸 iPhone）；iPhone Duo 外屏用 1398x2034（截图也要用 Duo 模拟器外屏截）。
//   版面按宽度等比缩放，截图按自己的像素比例放进下半截。
//   font.ttf：Noto Serif SC 可变字体（SIL OFL），https://github.com/google/fonts/raw/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf
//   shots：iPhone 6.9 寸模拟器（1320×2868）截的图，文件名对应下面 frames 里的 file，截法见 docs/user-flow.md「截图怎么更新」
let args = CommandLine.arguments
let fontURL = URL(fileURLWithPath: args[1])
let shots = URL(fileURLWithPath: args[2])
let out = URL(fileURLWithPath: args[3])
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

func rgb(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let paper = rgb(0xF7F6F2), ink = rgb(0x16150F), gray = rgb(0x6E6C64), vermilion = rgb(0xC23B22), line = rgb(0xE2DED4)

func serif(_ size: CGFloat, weight: CGFloat) -> NSFont {
    let desc = CTFontDescriptorCreateWithAttributes([
        kCTFontFamilyNameAttribute: "Noto Serif SC",
        kCTFontVariationAttribute: [0x77676874: weight],
    ] as CFDictionary)
    return CTFontCreateWithFontDescriptor(desc, size, nil) as NSFont
}

struct Frame { let file: String; let title: String; let sub: String }
let frames = [
    Frame(file: "capture", title: "拍一下，AI 认牌", sub: "手牌推倒对准一拍，每张牌都认出来"),
    Frame(file: "check-reviewing", title: "AI 再看一遍", sub: "先出结果，再逐张复核，认得又快又准"),
    Frame(file: "check", title: "看不清的，AI 给候选", sub: "标出哪张能和，点一下就定"),
    Frame(file: "result", title: "番数，自动算好", sub: "国标八十一番，谁付多少一清二楚"),
    Frame(file: "table", title: "一桌四人，一本账", sub: "庄家、风圈自动轮转，每局输赢随手记"),
    Frame(file: "settle", title: "打完，一键结账", sub: "最少几笔转账，账本图发到微信群"),
    Frame(file: "hand-detail", title: "每一局，怎么和的都在", sub: "点开账本里的一局，牌、番种、照片都能翻"),
]

let size = args.count > 4 ? args[4].split(separator: "x").compactMap { Double($0) } : [1320, 2868]
let W = CGFloat(size[0]), H = CGFloat(size[1])
/// 版面是按 1320 宽设计的，别的宽度等比缩放。
let k = W / 1320
let margin: CGFloat = 116 * k

for (i, f) in frames.enumerated() {
    guard let shot = NSImage(contentsOf: shots.appendingPathComponent(f.file + ".png")) else { fatalError(f.file) }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // 翻转成从上往下的坐标
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.translateBy(x: 0, y: H); ctx.scaleBy(x: 1, y: -1)
    let flipped = NSGraphicsContext(cgContext: ctx, flipped: true)
    NSGraphicsContext.current = flipped

    paper.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()

    // 朱红小印 + 序号
    // 矮的图（Duo 外屏）顶上留白少一点
    let top: CGFloat = H / W < 1.8 ? 150 * k : 230 * k
    let sealY = top
    vermilion.setFill()
    NSBezierPath(roundedRect: NSRect(x: margin, y: sealY, width: 14 * k, height: 14 * k), xRadius: 2 * k, yRadius: 2 * k).fill()
    let num = NSAttributedString(string: String(format: "%02d", i + 1), attributes: [
        .font: NSFont.systemFont(ofSize: 34 * k, weight: .regular), .foregroundColor: gray, .kern: 4 * k,
    ])
    num.draw(at: NSPoint(x: margin + 34 * k, y: sealY - 12 * k))

    let para = NSMutableParagraphStyle(); para.lineSpacing = 0
    let title = NSMutableAttributedString(string: f.title, attributes: [
        .font: serif(96 * k, weight: 620), .foregroundColor: ink, .kern: 5 * k, .paragraphStyle: para,
    ])
    // 标题里的「AI」用朱红、无衬线，突出拍照认牌
    if let r = f.title.range(of: "AI") {
        title.addAttributes([.foregroundColor: vermilion, .font: NSFont.systemFont(ofSize: 92 * k, weight: .semibold)],
                            range: NSRange(r, in: f.title))
    }
    title.draw(at: NSPoint(x: margin - 4 * k, y: top + 74 * k))
    let sub = NSAttributedString(string: f.sub, attributes: [
        .font: NSFont.systemFont(ofSize: 46 * k, weight: .regular), .foregroundColor: gray, .kern: 2 * k,
    ])
    sub.draw(at: NSPoint(x: margin, y: top + 226 * k))

    // 截图：等比缩小，圆角，细边，很淡的影子。6.9 寸时是原图的 0.70；矮的图按剩下的高度缩
    let pixels = shot.representations.first.map { CGSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? shot.size
    let shotTop = top + 470 * k
    let scale = min(W * 0.70 / pixels.width, (H - shotTop - 160 * k) / pixels.height)
    let sw = pixels.width * scale, sh = pixels.height * scale
    let rect = NSRect(x: (W - sw) / 2, y: shotTop, width: sw, height: sh)
    let radius: CGFloat = 62 * sw / 924
    let clip = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = rgb(0x3A3426, 0.10); shadow.shadowBlurRadius = 60 * k; shadow.shadowOffset = NSSize(width: 0, height: 24 * k)
    shadow.set()
    paper.setFill(); clip.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    shot.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
    line.setStroke(); clip.lineWidth = 2 * k; clip.stroke()

    NSGraphicsContext.restoreGraphicsState()
    // App Store 不收带透明通道的图，转成不透明 RGB
    let cg = rep.cgImage!
    let opaque = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    opaque.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
    let png = NSBitmapImageRep(cgImage: opaque.makeImage()!).representation(using: .png, properties: [:])!
    try! png.write(to: out.appendingPathComponent(String(format: "%02d-%@.png", i + 1, f.file)))
}
print("done")
