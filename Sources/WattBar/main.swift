import AppKit

let application = NSApplication.shared
let renderArguments = CommandLine.arguments
if let index = renderArguments.firstIndex(of: "--render-panel"), index + 1 < renderArguments.count {
    let scenario = index + 2 < renderArguments.count ? renderArguments[index + 2] : "charging"
    PanelRenderer.render(to: renderArguments[index + 1], scenario: scenario)
    exit(0)
}
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
