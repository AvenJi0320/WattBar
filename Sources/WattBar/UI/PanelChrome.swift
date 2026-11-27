import SwiftUI

struct PanelChrome: View {
    let store: PowerStore

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
        PowerPanelView(store: store)
            .background(shape.fill(Theme.panelFill))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            .clipShape(shape)
    }
}
