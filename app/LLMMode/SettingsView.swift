import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

/// Observable wrapper over ConfigStore shared by the Settings tabs.
@MainActor
final class ConfigModel: ObservableObject {
    @Published private(set) var values: [String: String] = [:]
    @Published private(set) var hasCustomLines = false
    @Published var saveError: String?
    let store: ConfigStore

    init(store: ConfigStore = ConfigStore()) {
        self.store = store
        reload()
    }

    func reload() {
        values = store.values()
        hasCustomLines = store.hasCustomLines()
    }

    func value(_ key: String) -> String { values[key] ?? "" }

    func set(_ key: String, _ value: String) {
        guard self.value(key) != value else { return }
        do { try store.set(key, value); saveError = nil } catch { saveError = error.localizedDescription }
        reload()
    }
}

struct SettingsView: View {
    @StateObject private var config = ConfigModel()

    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            BackendTab().tabItem { Label("Backend", systemImage: "server.rack") }
            MemoryTab().tabItem { Label("Memory", systemImage: "memorychip") }
            AppsTab().tabItem { Label("Apps", systemImage: "square.grid.2x2") }
        }
        .environmentObject(config)
        .frame(width: 480)
        .onAppear { config.reload() }
    }
}

/// notes shown on top of every tab
private struct SettingsNotes: View {
    @EnvironmentObject var model: StatusModel
    @EnvironmentObject var config: ConfigModel

    var body: some View {
        if config.hasCustomLines {
            Label("Config has custom lines; only CFG_* values are editable here.", systemImage: "exclamationmark.triangle")
                .font(.caption)
        }
        if model.status?.isOn == true {
            Label("Applies next time you turn LLM Mode on.", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
        if let e = config.saveError {
            Text(e).font(.caption).foregroundStyle(.red)
        }
    }
}

/// text field that writes to config on Enter or when it loses focus
private struct ConfigField: View {
    let title: String
    let key: String
    var prompt = ""
    @EnvironmentObject var config: ConfigModel
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(title, text: $text, prompt: Text(prompt))
            .focused($focused)
            .onAppear { text = config.value(key) }
            .onChange(of: config.value(key)) { _, v in if !focused { text = v } }
            .onSubmit { config.set(key, text) }
            .onChange(of: focused) { _, f in if !f { config.set(key, text) } }
    }
}

private struct GeneralTab: View {
    @AppStorage("confirmBeforeOn") private var confirmBeforeOn = true
    @AppStorage("relaunchOnOff") private var relaunchOnOff = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            SettingsNotes()
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            Toggle("Confirm before turning ON", isOn: $confirmBeforeOn)
            Toggle("Reopen apps when turning OFF", isOn: $relaunchOnOff)
        }
        .formStyle(.grouped)
    }
}

private struct BackendTab: View {
    @EnvironmentObject var model: StatusModel
    @EnvironmentObject var config: ConfigModel
    @State private var models: [String] = []
    private let options = ["auto", "lmstudio", "ollama", "llamacpp", "mlx", "custom"]

    var body: some View {
        Form {
            SettingsNotes()
            Section("Server") {
                Picker("Backend", selection: Binding(
                    get: { config.value("CFG_BACKEND").isEmpty ? "auto" : config.value("CFG_BACKEND") },
                    set: { config.set("CFG_BACKEND", $0 == "auto" ? "" : $0); loadModels() })) {
                    ForEach(options, id: \.self) { Text(label($0)).tag($0) }
                }
                if config.value("CFG_BACKEND") == "custom" {
                    ConfigField(title: "Start command", key: "CFG_SERVER_CMD", prompt: "llama-server -m model.gguf --port 1234")
                    ConfigField(title: "Stop command", key: "CFG_SERVER_STOP_CMD", prompt: "optional; default kills the pid")
                }
                if models.isEmpty {
                    ConfigField(title: "Model", key: "CFG_MODEL", prompt: "backend default")
                } else {
                    Picker("Model", selection: Binding(get: { config.value("CFG_MODEL") },
                                                       set: { config.set("CFG_MODEL", $0) })) {
                        Text("Backend default").tag("")
                        ForEach(modelChoices, id: \.self) { Text($0).tag($0) }
                    }
                }
                ConfigField(title: "Port", key: "CFG_PORT", prompt: "1234")
            }
            Section("Advanced") {
                ConfigField(title: "Extra server args", key: "CFG_SERVER_ARGS", prompt: "-c 32768")
                ConfigField(title: "Start timeout (s)", key: "CFG_START_TIMEOUT", prompt: "120")
            }
        }
        .formStyle(.grouped)
        .task { loadModels() }
    }

    /// keep a hand-typed model selectable even if the backend doesn't list it
    private var modelChoices: [String] {
        let cur = config.value("CFG_MODEL")
        return cur.isEmpty || models.contains(cur) ? models : [cur] + models
    }

    private func label(_ b: String) -> String {
        if b == "auto" { return "Auto" }
        return Format.backendName(b) + (model.status?.backends[b] == true ? "  ✓ installed" : "")
    }

    private func loadModels() { Task { models = await model.listModels() } }
}

private struct MemoryTab: View {
    @EnvironmentObject var model: StatusModel
    @EnvironmentObject var config: ConfigModel
    @State private var wiredGB: Double = 16
    @State private var reserveGB: Double = 4

    private var totalGB: Double { Double(model.status?.mem.totalMb ?? 16384) / 1024 }

    var body: some View {
        Form {
            SettingsNotes()
            Picker("GPU memory limit", selection: Binding(
                get: { !config.value("CFG_WIRED_MB").isEmpty },
                set: { config.set("CFG_WIRED_MB", $0 ? String(Int((wiredGB * 1024).rounded())) : "") })) {
                Text("Auto").tag(false)
                Text("Manual").tag(true)
            }
            if !config.value("CFG_WIRED_MB").isEmpty {
                Slider(value: $wiredGB, in: 4...max(5, totalGB - 2), step: 1) { Text("Limit") } onEditingChanged: { editing in
                    if !editing { config.set("CFG_WIRED_MB", String(Int(wiredGB.rounded()) * 1024)) }
                }
                Text("\(Int(wiredGB)) GB for the model").font(.caption).foregroundStyle(.secondary)
            } else {
                Slider(value: $reserveGB, in: 1...16, step: 1) { Text("Reserve for macOS") } onEditingChanged: { editing in
                    if !editing { config.set("CFG_RESERVE_MB", String(Int(reserveGB) * 1024)) }
                }
                Text("Auto = \(Int(totalGB)) GB total − \(Int(reserveGB)) GB reserve = \(Int(totalGB) - Int(reserveGB)) GB for the model")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            let w = Int(config.value("CFG_WIRED_MB"))
            wiredGB = w.map { Double($0) / 1024 } ?? max(4, totalGB - 4)
            reserveGB = Double((Int(config.value("CFG_RESERVE_MB")) ?? 4096) / 1024)
        }
    }
}

private struct AppsTab: View {
    @EnvironmentObject var config: ConfigModel
    private var raw: String { config.value("CFG_WHITELIST_EXTRA") }

    var body: some View {
        Form {
            SettingsNotes()
            Section("Quitting") {
                Toggle("Quit other apps when turning on", isOn: Binding(
                    get: { config.value("CFG_QUIT_APPS") == "1" },
                    set: { config.set("CFG_QUIT_APPS", $0 ? "1" : "") }))
                Text("Off by default. When on, apps not listed below are quit to free memory.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Always kept running") {
                Text(Whitelist.builtIn.joined(separator: ", ")).foregroundStyle(.secondary)
                Text("Plus the active backend's own app.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Your apps") {
                if let ids = Whitelist.ids(from: raw) {
                    ForEach(ids, id: \.self) { id in
                        HStack {
                            Text(displayName(id))
                            Text(id).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button { save(ids.filter { $0 != id }) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                        }
                    }
                    Menu("Add app…") {
                        ForEach(runningApps(excluding: ids), id: \.self) { id in
                            Button(displayName(id)) { save(ids + [id]) }
                        }
                        Divider()
                        Button("Choose from Applications…") {
                            if let id = pickApp(), !ids.contains(id) { save(ids + [id]) }
                        }
                    }
                } else {
                    ConfigField(title: "Whitelist regex", key: "CFG_WHITELIST_EXTRA")
                    Text("Your config uses a custom regex, so it is shown as text.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func save(_ ids: [String]) { config.set("CFG_WHITELIST_EXTRA", Whitelist.regex(from: ids)) }

    private func displayName(_ id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func runningApps(excluding ids: [String]) -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { !ids.contains($0) }
            .sorted()
    }

    private func pickApp() -> String? {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.application]
        p.directoryURL = URL(fileURLWithPath: "/Applications")
        guard p.runModal() == .OK, let url = p.url else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }
}
