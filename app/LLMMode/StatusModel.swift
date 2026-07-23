import Foundation

@MainActor
final class StatusModel: ObservableObject {
    @Published var serverUp = false
    @Published var freeRAM = "…"
    @Published var model = "…"
    @Published var host = "…"
    @Published var busy = false

    private func cli(_ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/local/bin/llm-mode")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
            _ = await self?.cli([sub])
            await self?.finishRun()
        }
    }
}
