import SwiftUI

struct StackedBarView: View {
    struct Segment: Identifiable {
        let id: String
        let value: Double
        let color: Color
    }

    let segments: [Segment]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let visible = segments.filter { $0.value > 0 }
        let sum = visible.reduce(0) { $0 + $1.value }
        GeometryReader { geometry in
            let gaps = CGFloat(max(0, visible.count - 1)) * 2
            let usable = max(0, geometry.size.width - gaps)
            HStack(spacing: 2) {
                ForEach(visible) { segment in
                    Rectangle()
                        .fill(segment.color.gradient)
                        .frame(width: sum > 0 ? max(3, usable * segment.value / sum) : 0)
                }
            }
        }
        .frame(height: 6)
        .background(Color.primary.opacity(0.07))
        .clipShape(Capsule())
        .animation(Theme.spring(reduceMotion), value: segments.map(\.value))
        .accessibilityHidden(true)
    }
}
