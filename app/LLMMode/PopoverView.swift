import SwiftUI
import AppKit

/// The B3 panel: header toggle, GPU ring + uptime, memory bar, client command.
struct PopoverView: View {
    @EnvironmentObject var model: StatusModel
    @AppStorage("confirmBeforeOn") private var confirmBeforeOn = true
    @State private var confirming = false

    private var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".llm-mode/log")
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                header
                Divider()
                if let err = model.error {
                    StatCard { Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption) }
                }
                Group { cards }
                    .disabled(model.error != nil)
                    .opacity(model.error != nil ? 0.4 : 1)
                iconBar
            }
            .padding(14)
            if confirming { ConfirmOnView(isPresented: $confirming) }
        }
        .frame(width: 320)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("llm-mode", image: "MenuOn").font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Toggle("LLM Mode", isOn: toggle)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(model.busy || model.status == nil || model.error != nil)
            }
            if let e = model.runError {
                Text(e).font(.caption).foregroundStyle(.red).lineLimit(2)
            }
        }
    }

    private var subtitle: String {
        guard let s = model.status else { return "…" }
        return "\(Format.backendName(s.backend)) · \(s.model ?? "-")"
    }

    /// reads the CLI's mode, so a failed on/off snaps back on the next refresh
    private var toggle: Binding<Bool> {
        Binding(
            get: { model.status?.isOn ?? false },
            set: { on in
                if !on { model.run("off") }
                else if confirmBeforeOn { confirming = true }
                else { model.run("on") }
            })
    }

    @ViewBuilder private var cards: some View {
        let s = model.status
        let mem = s?.mem ?? .zero
        HStack(spacing: 8) {
            StatCard {
                HStack {
                    RingGauge(fraction: mem.wiredLimitMb > 0 ? Double(mem.modelMb) / Double(mem.wiredLimitMb) : 0)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("GPU").font(.caption).foregroundStyle(.secondary)
                        Text(Format.gb(mem.modelMb)).font(.title3.weight(.semibold)).monospacedDigit()
                        Text("/ \(Format.gb(mem.wiredLimitMb)) GB").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            StatCard {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Uptime").font(.caption).foregroundStyle(.secondary)
                    Text(uptime(s)).font(.title3.weight(.semibold)).monospacedDigit()
                    Text("port \(s?.port ?? 0)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        StatCard { MemoryBar(mem: mem) }
        StatCard { CopyRow(label: "Client", text: "client-connect.sh \(NSUserName())@\(s?.host ?? "…")") }
    }

    private func uptime(_ s: Status?) -> String {
        guard let s, s.isOn, let start = s.startedAt else { return "Off" }
        return Format.uptime(from: start)
    }

    private var iconBar: some View {
        HStack {
            Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh")
            Spacer()
            Button {
                NSWorkspace.shared.open([logURL],
                                        withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"),
                                        configuration: NSWorkspace.OpenConfiguration())
            } label: { Label("Logs", systemImage: "list.bullet.rectangle") }
            Spacer()
            SettingsLink { Label("Settings", systemImage: "gearshape") }
                .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
            Spacer()
            Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }.help("Quit")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .font(.callout)
    }
}
