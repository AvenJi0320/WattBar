import SwiftUI
import WattBarCore

struct FooterView: View {
    let snapshot: PowerSnapshot

    private var summary: String {
        var parts: [String] = []
        if snapshot.state == .onBattery {
            parts.append("电池供电")
        } else if snapshot.input.watts != nil {
            parts.append("适配器输入 \(PowerFormatter.text(snapshot.input))")
        }
        if snapshot.state != .onBattery, snapshot.adapterLoss.watts != nil {
            parts.append("转换损耗 \(PowerFormatter.text(snapshot.adapterLoss))")
        }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        Text(summary)
            .font(.system(size: 10.5))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
