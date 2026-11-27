import SwiftUI
import WattBarCore

struct PowerPanelView: View {
    let store: PowerStore

    var body: some View {
        let snapshot = store.snapshot
        let values = store.values

        VStack(spacing: Theme.spacing) {
            ConsumptionCardView(snapshot: snapshot, values: values)
                .frame(minHeight: Theme.minCardHeight, alignment: .top)
                .padding(.leading, Theme.gaugeWidth + Theme.spacing)
                .overlay(alignment: .leading) {
                    ChargeGaugeView(snapshot: snapshot, primary: values.primary)
                        .frame(width: Theme.gaugeWidth)
                }
            FooterView(snapshot: snapshot)
        }
        .padding(Theme.padding)
        .frame(width: Theme.panelWidth(for: snapshot.externalDevices))
    }
}
