import SwiftUI

enum LeanoraTheme {
    static let canvas = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.07, green: 0.10, blue: 0.08, alpha: 1) : UIColor(red: 0.965, green: 0.957, blue: 0.93, alpha: 1) })
    static let surface = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.12, green: 0.16, blue: 0.13, alpha: 1) : .white })
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.62, green: 0.82, blue: 0.68, alpha: 1) : UIColor(red: 0.17, green: 0.34, blue: 0.25, alpha: 1) })
    static let ink = Color.primary
}

struct LeanoraMark: View {
    var size: CGFloat = 60
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24).fill(LeanoraTheme.accent)
            Path { path in
                path.move(to: CGPoint(x: size * 0.31, y: size * 0.26))
                path.addLine(to: CGPoint(x: size * 0.31, y: size * 0.72))
                path.addLine(to: CGPoint(x: size * 0.70, y: size * 0.72))
                path.move(to: CGPoint(x: size * 0.48, y: size * 0.53))
                path.addLine(to: CGPoint(x: size * 0.69, y: size * 0.30))
            }.stroke(LeanoraTheme.canvas, style: StrokeStyle(lineWidth: size * 0.095, lineCap: .round, lineJoin: .round))
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(LeanoraTheme.canvas)
            .background(LeanoraTheme.accent, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct SectionEyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
    }
}

struct FeatureLine: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title3).foregroundStyle(LeanoraTheme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
