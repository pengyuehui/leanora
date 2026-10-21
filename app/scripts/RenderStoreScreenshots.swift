import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Export new marketing compositions around unmodified, real XCTest screenshots.
// swiftc RenderStoreScreenshots.swift -o <binary>; <binary> <app/store>
struct Shot: Decodable { let id: String; let source: String; let section: String; let title: String; let body: String; let blue: Bool }
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let shots = try JSONDecoder().decode([Shot].self, from: Data(contentsOf: root.appendingPathComponent("screenshots.json")))
let rgb = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: rgb, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, 1])!
}
func load(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Missing screenshot: \(url.path)") }
    return image
}
func bitmap(_ width: Int, _ height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: rgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}
func export(_ image: CGImage, _ url: URL) {
    let target = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(target, image, nil)
    precondition(CGImageDestinationFinalize(target), "PNG export failed")
}
func text(_ value: String, on context: CGContext, x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat, size: CGFloat, ink: CGColor, bold: Bool = false) {
    let font = CTFontCreateWithName((bold ? "PingFangSC-Semibold" : "PingFangSC-Regular") as CFString, size, nil)
    let string = NSAttributedString(string: value, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink])
    let setter = CTFramesetterCreateWithAttributedString(string)
    let box = CGRect(x: x, y: CGFloat(context.height) - top - height, width: width, height: height)
    let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: box, transform: nil), nil)
    precondition(CTFrameGetVisibleStringRange(frame).length == string.length, "Text clipped: \(value)")
    context.textMatrix = .identity
    CTFrameDraw(frame, context)
}
func framed(_ image: CGImage, on context: CGContext, x: CGFloat, top: CGFloat, width: CGFloat, radius: CGFloat) {
    let height = width * CGFloat(image.height) / CGFloat(image.width)
    let rect = CGRect(x: x, y: CGFloat(context.height) - top - height, width: width, height: height)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.saveGState(); context.addPath(path); context.clip(); context.interpolationQuality = .high; context.draw(image, in: rect); context.restoreGState()
    context.setStrokeColor(color(0xCBD4E6)); context.setLineWidth(2); context.addPath(path); context.strokePath()
}
let icon = load(root.appendingPathComponent("brand/app-icon-1024.png"))
for (width, height, folder) in [(1206, 2622, "iphone-medium"), (1320, 2868, "iphone-large")] {
    let output = root.appendingPathComponent("zh-Hans/\(folder)")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let s = CGFloat(width) / 1320
    for (index, shot) in shots.enumerated() {
        let context = bitmap(width, height)
        let background = color(shot.blue ? 0x2155D6 : 0xF1F5FC)
        let foreground = color(shot.blue ? 0xFFFFFF : 0x122546)
        let secondary = color(shot.blue ? 0xDFE8FF : 0x526580)
        context.setFillColor(background); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        framed(icon, on: context, x: 84*s, top: 82*s, width: 76*s, radius: 18*s)
        text("Leanora Fitness", on: context, x: 184*s, top: 88*s, width: 1000*s, height: 70*s, size: 44*s, ink: foreground, bold: true)
        text(String(format: "%02d", index + 1) + "  /  " + shot.section, on: context, x: 84*s, top: 220*s, width: 1152*s, height: 64*s, size: 30*s, ink: secondary)
        text(shot.title, on: context, x: 78*s, top: 296*s, width: 1170*s, height: 304*s, size: (index == 6 ? 96 : 104)*s, ink: foreground, bold: true)
        text(shot.body, on: context, x: 84*s, top: 600*s, width: 1152*s, height: 132*s, size: 38*s, ink: secondary)
        let source = load(root.appendingPathComponent("zh-Hans/source/\(shot.source).png"))
        precondition(source.width == 1398 && source.height == 2034, "Expected unmodified iPhone Duo outer-display screenshot")
        framed(source, on: context, x: 84*s, top: 822*s, width: 1152*s, radius: 48*s)
        text("真实 App 画面 · 示例记录", on: context, x: 84*s, top: 2615*s, width: 1152*s, height: 72*s, size: 30*s, ink: secondary)
        text("记录，每一天。", on: context, x: 84*s, top: 2720*s, width: 1152*s, height: 60*s, size: 32*s, ink: foreground, bold: true)
        export(context.makeImage()!, output.appendingPathComponent("\(shot.id).png"))
    }
}
let sheet = bitmap(1584, 1860)
sheet.setFillColor(color(0xE6ECF6)); sheet.fill(CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height))
text("Leanora Fitness  /  商店展示素材", on: sheet, x: 48, top: 36, width: 1488, height: 80, size: 38, ink: color(0x122546), bold: true)
for (index, shot) in shots.enumerated() {
    let image = load(root.appendingPathComponent("zh-Hans/iphone-large/\(shot.id).png"))
    let x = CGFloat(48 + (index % 4) * 384), top = CGFloat(146 + (index / 4) * 836)
    framed(image, on: sheet, x: x, top: top, width: 336, radius: 12)
}
text("7 张真实页面 · 中文首发文案 · 1024 px 图标", on: sheet, x: 48, top: 1780, width: 1488, height: 55, size: 28, ink: color(0x526580))
export(sheet.makeImage()!, root.appendingPathComponent("contact-sheet.png"))
print("Exported 14 store compositions and one contact sheet; source UI unchanged.")
