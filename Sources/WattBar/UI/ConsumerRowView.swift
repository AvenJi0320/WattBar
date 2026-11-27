import SwiftUI
import WattBarCore

struct ConsumerRowView: View {
    let icon: String
    let title: String
    let color: Color
    let quality: Quality
    let watts: Double?
    let total: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var valueText: String {
        PowerFormatter.text(Metric(watts: watts, quality: watts == nil ? .unavailable : quality))
    }

    private var percentText: String {
        guard let watts, let total, total > 0 else { return "" }
        return "\(Int((min(1, max(0, watts / total)) * 100).rounded()))%"
    }

    var body: some View {
        HStack(spacing: 8) {
            IconTile(systemName: icon, color: color)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .fixedSize()
            if let tag = PowerFormatter.tag(quality) {
                TagPill(text: tag)
            }
            Spacer(minLength: 4)
            Text(valueText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(quality == .contracted || quality == .allocated ? .secondary : .primary)
                .contentTransition(.numericText())
                .animation(Theme.animation(reduceMotion), value: valueText)
            Text(percentText)
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)功率 \(valueText)，\(Theme.qualityLabel(quality))")
    }
}
