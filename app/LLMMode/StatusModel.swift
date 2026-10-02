import Foundation

struct CLIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class StatusModel: ObservableObject {
    static let missingCLI = "llm-mode CLI not found at /usr/local/bin/llm-mode — run install.sh"

    @Published var status: Status?
    @Published var error: String?      // status can't be read at all
    @Published var runError: String?   // last on/off failed
    @Published var busy = false
    private var timer: Timer?

    // Touches no published state, so it's safe to run off the main actor
    // (called from Task.detached below) without blocking the UI.
    nonisolated func cli(_ args: [String]) -> (code: Int32, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/local/bin/llm-mode")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
        } catch {
            return (127, Self.missingCLI)
        }
        // Read before waitUntilExit: the child can block writing to a full
        // pipe if we wait first, deadlocking against a process that's
        // waiting on us to drain it.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    func refresh() {
        Task.detached { [weak self] in
            guard let self else { return }
            let r = self.cli(["status", "--json"])
            await self.apply(code: r.code, out: r.out)
        }
    }

    func apply(code: Int32, out: String) {
        let line = Format.lastLine(out)
        if code == 0, let s = try? Status.decode(Data(line.utf8)) {
            status = s
            error = nil
        } else if code == 127 {
            error = line
        } else if out.contains("usage:") {
            error = "llm-mode CLI is too old for this app — run install.sh"
        } else {
            error = "llm-mode status failed: \(line)"
        }
    }

    /// refresh every 3 s while the panel is open
    func startPolling() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func run(_ sub: String) {
        busy = true
        runError = nil
        var args = [sub]
        if sub == "off" && UserDefaults.standard.bool(forKey: "relaunchOnOff") { args.append("--relaunch") }
        Task.detached { [weak self] in
            guard let self else { return }
            // nonisolated, synchronous call: runs on this detached task's
            // thread, not on the main actor.
            let r = self.cli(args)
            await self.finishRun(sub, r)
        }
    }

    private func finishRun(_ sub: String, _ r: (code: Int32, out: String)) {
        busy = false
        if r.code != 0 {
            let last = Format.lastLine(r.out)
            runError = last.isEmpty ? "llm-mode \(sub) failed (exit \(r.code))" : last
        }
        refresh()
    }

    /// app names `on` would quit; throws with the CLI's refusal reason
    func appsToQuit() async throws -> [String] {
        struct Preview: Decodable { let quit: [String] }
        let r = await Task.detached { self.cli(["on", "--dry-run", "--json"]) }.value
        let line = Format.lastLine(r.out)
        guard r.code == 0, let p = try? JSONDecoder().decode(Preview.self, from: Data(line.utf8)) else {
            throw CLIError(message: line.isEmpty ? "llm-mode on --dry-run failed" : line)
        }
        return p.quit
    }

    /// models of the configured backend; empty when it can't list them
    func listModels() async -> [String] {
        let r = await Task.detached { self.cli(["models"]) }.value
        guard r.code == 0 else { return [] }
        return r.out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }
}
