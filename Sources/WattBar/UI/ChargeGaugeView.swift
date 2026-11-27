import SwiftUI
import WattBarCore

struct ChargeGaugeView: View {
    let snapshot: PowerSnapshot
    let primary: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var title: String {
        snapshot.state == .onBattery ? "放电功率" : "充电功率"
    }

    private var statusText: String {
        switch snapshot.state {
        case .charging: "正在充电"
        case .pluggedIdle: (snapshot.batteryPercent ?? 0) >= 100 ? "已充满" : "暂停充电"
        case .pluggedDraining: "电池补电"
        case .onBattery:
            if let minutes = snapshot.timeToEmptyMin {
                "剩余 \(minutes / 60):" + String(format: "%02d", minutes % 60)
            } else {
                "使用电池"
            }
        case .unsupported: "此 Mac 不支持"
        }
    }

    private var pillText: String {
        switch snapshot.state {
        case .charging, .pluggedIdle, .pluggedDraining:
            if let watts = snapshot.adapterWatts { return "\(statusText) · \(watts)W" }
            return statusText
        case .onBattery, .unsupported:
            return statusText
        }
    }

    private var accent: Color {
        switch snapshot.state {
        case .charging: .green
        case .pluggedDraining, .onBattery: .orange
        case .pluggedIdle, .unsupported: .secondary
        }
    }

    private var tint: AnyShapeStyle? {
        let isDark = colorScheme == .dark
        switch snapshot.state {
        case .charging:
            return AnyShapeStyle(LinearGradient(
                colors: [Color.green.opacity(isDark ? 0.20 : 0.16), Color.mint.opacity(isDark ? 0.05 : 0.04)],
                startPoint: .top, endPoint: .bottom))
        case .pluggedDraining, .onBattery:
            return AnyShapeStyle(LinearGradient(
                colors: [Color.orange.opacity(isDark ? 0.18 : 0.16), Color.orange.opacity(isDark ? 0.04 : 0.03)],
                startPoint: .top, endPoint: .bottom))
        case .pluggedIdle, .unsupported:
            return nil
        }
    }

    private var arcStyle: AnyShapeStyle {
        switch snapshot.state {
        case .charging:
            AnyShapeStyle(LinearGradient(colors: [.mint, .green], startPoint: .bottomLeading, endPoint: .topTrailing))
        case .pluggedDraining, .onBattery:
            AnyShapeStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .bottomLeading, endPoint: .topTrailing))
        case .pluggedIdle, .unsupported:
            AnyShapeStyle(Color.secondary.opacity(0.5))
        }
    }

    private var numberText: String {
        let metric = Metric(watts: primary, quality: primary == nil ? .unavailable : .measured)
        return PowerFormatter.text(metric).replacingOccurrences(of: " W", with: "")
    }

    private var progress: Double {
        guard let primary else { return 0 }
        let denominator = Double(snapshot.adapterWatts ?? 100)
        return min(1, max(0, primary / max(denominator, 1)))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geometry in
                let diameter = min(Theme.maxRingDiameter, geometry.size.width, geometry.size.height)
                ring(diameter: diameter)
                    .frame(width: diameter, height: diameter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 5) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(pillText)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card(tint: tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(PowerFormatter.text(Metric(watts: primary, quality: .measured)))，\(pillText)")
    }

    private func ring(diameter: CGFloat) -> some View {
        let lineWidth = max(6, diameter * 0.066)
        return ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * progress)
                .stroke(arcStyle, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
                .animation(Theme.spring(reduceMotion), value: progress)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(numberText)
                        .font(.system(size: diameter * 0.27, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(Theme.animation(reduceMotion), value: numberText)
                    if primary != nil {
                        Text("W")
                            .font(.system(size: diameter * 0.115, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                if let percent = snapshot.batteryPercent {
                    Label("\(percent)%", systemImage: Theme.batterySymbol(percent))
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: max(9, diameter * 0.086), weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, diameter * 0.16)
        }
    }
}
