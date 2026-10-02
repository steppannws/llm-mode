import SwiftUI

@main
struct LLMModeApp: App {
    @StateObject private var status = StatusModel()

    init() {
        let status = self.status
        Task { @MainActor in
            status.refresh()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView().environmentObject(status)
        } label: {
            Image(systemName: status.busy ? "ellipsis.circle"
                              : status.status?.serverUp == true ? "brain.fill" : "brain")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(status)
        }
    }
}
