import SwiftUI

/// Shown over the panel before `on`: lists the apps that will quit.
struct ConfirmOnView: View {
    @EnvironmentObject var model: StatusModel
    @Binding var isPresented: Bool
    @AppStorage("confirmBeforeOn") private var confirmBeforeOn = true
    @State private var apps: [String]?
    @State private var loadError: String?
    @State private var dontAsk = false

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.35)).onTapGesture { isPresented = false }
            VStack(alignment: .leading, spacing: 8) {
                Text("Turn LLM Mode on?").font(.headline)
                if let loadError {
                    Text(loadError).font(.caption).foregroundStyle(.red)
                } else if let apps {
                    Text("These apps will quit to free memory:").font(.caption).foregroundStyle(.secondary)
                    Text(Format.quitSummary(apps))
                } else {
                    ProgressView().controlSize(.small)
                }
                Toggle("Don't ask again", isOn: $dontAsk).toggleStyle(.checkbox).font(.caption)
                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }.keyboardShortcut(.cancelAction)
                    Button("Turn On") {
                        if dontAsk { confirmBeforeOn = false }
                        isPresented = false
                        model.run("on")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(apps == nil)
                }
            }
            .padding(14)
            .frame(width: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 12)
        }
        .task {
            do {
                let list = try await model.appsToQuit()
                guard !Task.isCancelled, isPresented else { return }
                if list.isEmpty {
                    // nothing to confirm: skip the overlay and turn on directly
                    isPresented = false
                    model.run("on")
                } else {
                    apps = list
                }
            } catch { loadError = error.localizedDescription }
        }
    }
}
