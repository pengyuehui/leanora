import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
NSColor(red: 0.12, green: 0.34, blue: 0.77, alpha: 1).setFill()
let mark = NSBezierPath(roundedRect: NSRect(x: 152, y: 152, width: 720, height: 720), xRadius: 172, yRadius: 172)
mark.fill()
NSColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1).setStroke()
let path = NSBezierPath()
path.lineWidth = 68
path.lineCapStyle = .round
path.lineJoinStyle = .round
path.move(to: NSPoint(x: 375, y: 685))
path.line(to: NSPoint(x: 375, y: 354))
path.line(to: NSPoint(x: 656, y: 354))
path.move(to: NSPoint(x: 498, y: 491))
path.line(to: NSPoint(x: 649, y: 656))
path.stroke()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("AppIcon.png"))
let contents = """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try contents.write(to: output.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
