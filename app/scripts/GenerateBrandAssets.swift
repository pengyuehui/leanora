import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Deterministic size/color export of the checked-in imagegen master.
// Compile with swiftc, then run <binary> <appiconset-output> [master-png].
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let source = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : root.appendingPathComponent("store/brand/icon-master.png")
guard let reader = CGImageSourceCreateWithURL(source as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(reader, 0, nil) else { fatalError("Missing icon master: \(source.path)") }
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.interpolationQuality = .high
context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent("AppIcon.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot export AppIcon.png") }
let contents = """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try contents.write(to: output.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
