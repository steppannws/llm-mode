import Foundation

/// Decoded `llm-mode status --json`.
struct Status: Decodable, Equatable {
    struct Mem: Decodable, Equatable {
        let totalMb: Int
        let wiredLimitMb: Int
        let reserveMb: Int
        let modelMb: Int
        let freeMb: Int

        static let zero = Mem(totalMb: 0, wiredLimitMb: 0, reserveMb: 0, modelMb: 0, freeMb: 0)

        /// memory bar segments in MB; "other" is whatever isn't model, free or reserve
        var segments: (model: Int, other: Int, reserve: Int, free: Int) {
            (modelMb, max(0, totalMb - modelMb - freeMb - reserveMb), reserveMb, freeMb)
        }
    }

    let backend: String?
    let model: String?
    let port: Int
    let server: String
    let host: String?
    let mode: String
    let startedAt: Int?
    let mem: Mem
    let backends: [String: Bool]

    var serverUp: Bool { server == "up" }
    var isOn: Bool { mode == "on" }

    static func decode(_ data: Data) throws -> Status {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(Status.self, from: data)
    }
}

enum Format {
    /// "17", "5.1": one decimal below 10 GB
    static func gb(_ mb: Int) -> String {
        let g = Double(mb) / 1024
        return g < 10 && g.rounded() != g ? String(format: "%.1f", g) : String(Int(g.rounded()))
    }

    static func uptime(from start: Int, now: Date = Date()) -> String {
        let secs = max(0, Int(now.timeIntervalSince1970) - start)
        let d = secs / 86400, h = secs % 86400 / 3600, m = secs % 3600 / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func backendName(_ b: String?) -> String {
        switch b {
        case "lmstudio"?: "LM Studio"
        case "ollama"?: "Ollama"
        case "llamacpp"?: "llama.cpp"
        case "mlx"?: "MLX"
        case "custom"?: "Custom"
        case nil: "No backend"
        case let other?: other
        }
    }

    static func quitSummary(_ apps: [String]) -> String {
        apps.count <= 4 ? apps.joined(separator: ", ")
                        : apps.prefix(4).joined(separator: ", ") + " +\(apps.count - 4) more"
    }

    /// last non-empty line: the JSON, after any warnings the CLI printed first
    static func lastLine(_ s: String) -> String {
        s.split(separator: "\n").last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map(String.init) ?? ""
    }
}
