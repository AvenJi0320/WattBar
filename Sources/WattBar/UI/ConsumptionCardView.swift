import SwiftUI
import WattBarCore

struct ConsumptionCardView: View {
    let snapshot: PowerSnapshot
    let values: PowerStore.DisplayValues

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var totalText: String {
        PowerFormatter.text(Metric(watts: values.total, quality: values.total == nil ? .unavailable : .measured))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("整机功耗")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(totalText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Theme.animation(reduceMotion), value: totalText)
            }

            StackedBarView(segments: [
                .init(id: "display", value: values.display ?? 0, color: Theme.displayColor),
                .init(id: "computer", value: values.computer ?? 0, color: Theme.computerColor),
                .init(id: "external", value: values.external ?? 0, color: Theme.externalColor),
            ])

            VStack(alignment: .leading, spacing: 9) {
                ConsumerRowView(
                    icon: "display", title: "屏幕", color: Theme.displayColor,
                    quality: snapshot.display.quality, watts: values.display, total: values.total
                )
                ConsumerRowView(
                    icon: "laptopcomputer", title: "电脑", color: Theme.computerColor,
                    quality: snapshot.computer.quality, watts: values.computer, total: values.total
                )
                ConsumerRowView(
                    icon: "cable.connector", title: "外接设备", color: Theme.externalColor,
                    quality: snapshot.external.quality, watts: values.external, total: values.total
                )
                ExternalDeviceList(devices: snapshot.externalDevices, parentQuality: snapshot.external.quality)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card()
    }
}
