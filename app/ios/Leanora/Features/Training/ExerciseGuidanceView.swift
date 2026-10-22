import SwiftUI
import ImageIO
import UIKit

struct ExerciseGuidanceView: View {
    let exerciseID: UUID
    let name: String
    var body: some View {
        List {
            Section { Text(name).font(.title2.weight(.semibold)) }
            if let guide = ExerciseGuideCatalog.guide(for: exerciseID) {
                ExerciseGuideSections(guide: guide, name: name)
            } else {
                ContentUnavailableView("暂无内置指导", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .navigationTitle("动作指导").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
    }
}

struct ExerciseGuideSections: View {
    let guide: ExerciseGuide
    let name: String
    var body: some View {
        Section {
            ExerciseGuideGallery(guide: guide, name: name)
            Text("图示动作：\(guide.demoName)").font(.caption).foregroundStyle(.secondary)
            if let note = guide.variantNote {
                Text(note).font(.subheadline).accessibilityIdentifier("exercise.guide.variant")
            }
        } header: { Text("动作图示") } footer: { Text("左右滑动切换图片，轻点查看大图。图片可离线查看。") }
        Section("动作资料") {
            LabeledContent("类型", value: guide.category)
            LabeledContent("难度", value: guide.level)
            if !guide.primaryMuscles.isEmpty { LabeledContent("主要肌群", value: guide.primaryMuscles.joined(separator: "、")) }
            if !guide.secondaryMuscles.isEmpty { LabeledContent("辅助肌群", value: guide.secondaryMuscles.joined(separator: "、")) }
        }
        if !guide.instructions.isEmpty {
            Section("动作步骤") { steps(guide.instructions) }
        }
        if !guide.originalInstructions.isEmpty {
            Section(guide.instructions.isEmpty ? "动作步骤（英文原文）" : "来源原文（英文）") {
                if guide.instructions.isEmpty {
                    steps(guide.originalInstructions)
                } else {
                    DisclosureGroup("查看英文原文") { steps(guide.originalInstructions) }
                }
            }
        }
        Section("指导素材来源") {
            Text(guide.sourceName).font(.headline).accessibilityIdentifier("exercise.guide.source")
            Text(guide.credit).font(.footnote)
            if let url = URL(string: guide.licenseURL) { Link(guide.license, destination: url) }
            if let url = URL(string: guide.sourceURL) { Link("查看素材来源", destination: url) }
            Text(guide.modifications).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func steps(_ values: [String]) -> some View {
        ForEach(Array(values.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top, spacing: 12) {
                Text("\(index + 1)").font(.subheadline.weight(.semibold)).foregroundStyle(LeanoraTheme.accent).frame(minWidth: 22)
                Text(step).fixedSize(horizontal: false, vertical: true)
            }.padding(.vertical, 4).accessibilityElement(children: .combine)
                .accessibilityIdentifier("exercise.guide.step.\(index)")
        }
    }
}

private struct ExerciseGuideGallery: View {
    let guide: ExerciseGuide
    let name: String
    @State private var selection = 0
    @State private var enlarged = false
    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $selection) {
                ForEach(guide.images.indices, id: \.self) { index in
                    Button { enlarged = true } label: {
                        ExerciseGuideImage(path: guide.images[index], maxPixels: 800)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.buttonStyle(.plain).tag(index)
                        .accessibilityLabel("\(name)，指导图 \(index + 1)，查看大图")
                        .accessibilityIdentifier("exercise.guide.zoom.\(index)")
                }
            }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 12))
            ExerciseGuidePageControls(selection: $selection, count: guide.images.count)
        }
        .fullScreenCover(isPresented: $enlarged) {
            NavigationStack {
                VStack(spacing: 20) {
                    TabView(selection: $selection) {
                        ForEach(guide.images.indices, id: \.self) { index in
                            ExerciseGuideImage(path: guide.images[index], maxPixels: 1280)
                                .tag(index).accessibilityLabel("\(name)，指导图 \(index + 1)")
                        }
                    }.tabViewStyle(.page(indexDisplayMode: .never))
                    ExerciseGuidePageControls(selection: $selection, count: guide.images.count).padding(.horizontal)
                }
                .padding(.vertical).background(LeanoraTheme.canvas)
                .navigationTitle(name).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("关闭大图") { enlarged = false }.accessibilityIdentifier("exercise.guide.closeImage")
                } }
            }
        }
    }
}

private struct ExerciseGuidePageControls: View {
    @Binding var selection: Int
    let count: Int
    var body: some View {
        HStack {
            Button { selection = max(0, selection - 1) } label: { Label("上一张", systemImage: "chevron.left") }
                .frame(minWidth: 44, minHeight: 44)
                .disabled(selection == 0).accessibilityIdentifier("exercise.guide.previous")
            Spacer(minLength: 8)
            Text("\(selection + 1) / \(count)").monospacedDigit().font(.subheadline).accessibilityIdentifier("exercise.guide.page")
            Spacer(minLength: 8)
            Button { selection = min(count - 1, selection + 1) } label: { Label("下一张", systemImage: "chevron.right") }
                .frame(minWidth: 44, minHeight: 44)
                .disabled(selection == count - 1).accessibilityIdentifier("exercise.guide.next")
        }.labelStyle(.iconOnly).buttonStyle(.borderless).font(.subheadline).frame(minHeight: 44)
    }
}

struct ExerciseGuideImage: View {
    let path: String
    var maxPixels = 160
    var body: some View {
        Group {
            if let image = GuideImageCache.shared.image(path: path, maxPixels: maxPixels) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary).padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Workout Guide's original PNGs are white line art on transparency.
        .background(path.hasPrefix("workout/") ? Color(red: 0.09, green: 0.19, blue: 0.31) : .white)
    }
}

@MainActor private final class GuideImageCache {
    static let shared = GuideImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.totalCostLimit = 24 * 1024 * 1024 }
    func image(path: String, maxPixels: Int) -> UIImage? {
        let key = "\(maxPixels):\(path)" as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let url = ExerciseGuideCatalog.imageURL(for: path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixels,
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}
