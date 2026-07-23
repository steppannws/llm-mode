import Foundation

@MainActor
final class StatusModel: ObservableObject {
    @Published var serverUp = false
    @Published var freeRAM = "…"
    @Published var model = "…"
    @Published var host = "…"
    @Published var busy = false

    // Touches no published state, so it's safe to run off the main actor
    // (called from Task.detached in run(_:) below) without blocking the UI.
    nonisolated private func cli(_ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/local/bin/llm-mode")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
        } catch {
            return "error: llm-mode CLI not found at /usr/local/bin/llm-mode — run install.sh"
        }
        // Read before waitUntilExit: the child can block writing to a full
        // pipe if we wait first, deadlocking against a process that's
        // waiting on us to drain it.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    func refresh() {
        let out = cli(["status"])
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "server":   serverUp = (parts[1] == "up")
            case "free RAM": freeRAM = parts[1]
            case "model":    model = parts[1]
            case "host":     host = parts[1]
            default: break
            }
        }
    }

    private func finishRun() {
        busy = false
        refresh()
    }

    func run(_ sub: String) {
        busy = true
        Task.detached { [weak self] in
            guard let self else { return }
            // nonisolated, synchronous call: runs on this detached task's
            // thread, not on the main actor.
            _ = self.cli([sub])
            await self.finishRun()
        }
    }
}
