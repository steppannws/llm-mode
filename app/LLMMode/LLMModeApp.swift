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
            if status.busy {
                Image(systemName: "ellipsis.circle")
            } else {
                Image(status.status?.serverUp == true ? "MenuOn" : "MenuOff")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(status)
        }
    }
}
