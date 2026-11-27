import AppKit
import SwiftUI
import WattBarCore

enum Theme {
    static let displayColor = Color.cyan
    static let computerColor = Color.indigo
    static let externalColor = Color.orange
    static let minPanelWidth: CGFloat = 440
    static let maxPanelWidth: CGFloat = 620
    static let gaugeWidth: CGFloat = 150
    static let minCardHeight: CGFloat = 176
    static let maxRingDiameter: CGFloat = 122
    static let padding: CGFloat = 14
    static let spacing: CGFloat = 10
    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 14
    static let panelRadius: CGFloat = 22
    static let panelFill = Color(nsColor: NSColor(name: "WattBarPanelFill") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .windowBackgroundColor
            : NSColor(white: 1, alpha: 1)
    })
    static let deviceNameFontSize: CGFloat = 11
    static let deviceNameBaseWidth: CGFloat = 84

    static func panelWidth(for devices: [ExternalDevice]) -> CGFloat {
        let font = NSFont.systemFont(ofSize: deviceNameFontSize)
        let widest = devices.map {
            ($0.name as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        let extra = max(0, ceil(widest) - deviceNameBaseWidth)
        return min(maxPanelWidth, minPanelWidth + extra)
    }

    static func batterySymbol(_ percent: Int) -> String {
        switch percent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }

    static func qualityLabel(_ quality: Quality) -> String {
        switch quality {
        case .measured: "实测"
        case .derived: "推算"
        case .contracted: "协商上限"
        case .allocated: "分配上限"
        case .unavailable: "不可用"
        }
    }

    static func animation(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.25)
    }

    static func spring(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }
}

struct CardBackground: ViewModifier {
    let tint: AnyShapeStyle?

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        if colorScheme == .dark {
            content
                .background(shape.fill(tint ?? AnyShapeStyle(Color.primary.opacity(0.045))))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(Color(white: 0.965))
                        if let tint { shape.fill(tint) }
                    }
                }
                .overlay(shape.strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5))
        }
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground(tint: nil))
    }

    func card(tint: AnyShapeStyle?) -> some View {
        modifier(CardBackground(tint: tint))
    }
}

struct IconTile: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.gradient))
    }
}

struct TagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .fixedSize()
    }
}
