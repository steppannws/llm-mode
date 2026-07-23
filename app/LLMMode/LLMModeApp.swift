import SwiftUI

@main
struct LLMModeApp: App {
    @StateObject private var status = StatusModel()

    var body: some Scene {
        MenuBarExtra("LLM", systemImage: status.serverUp ? "brain.fill" : "brain") {
            Text("\(status.model) — \(status.serverUp ? "up" : "down")")
            Text("free RAM: \(status.freeRAM)")
            Text("host: \(status.host)")
            Divider()
            Button("LLM Mode ON")  { status.run("on") }.disabled(status.busy)
            Button("LLM Mode OFF") { status.run("off") }.disabled(status.busy)
            Button("Refresh")      { status.refresh() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .onChange(of: status.busy) { _, _ in status.refresh() }
    }
}
