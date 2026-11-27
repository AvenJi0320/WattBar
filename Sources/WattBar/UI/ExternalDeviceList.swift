import SwiftUI
import WattBarCore

struct ExternalDeviceList: View {
    let devices: [ExternalDevice]
    let parentQuality: Quality

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if devices.isEmpty {
                Text("无外接取电设备")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(devices) { device in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.externalColor.opacity(0.6))
                            .frame(width: 4, height: 4)
                        Text(device.name)
                            .font(.system(size: Theme.deviceNameFontSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if device.quality != parentQuality, let tag = PowerFormatter.tag(device.quality) {
                            TagPill(text: tag)
                        }
                        Spacer(minLength: 4)
                        Text(PowerFormatter.text(Metric(watts: device.watts, quality: device.quality)))
                            .font(.system(size: 11, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    .padding(.trailing, 38)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.leading, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
