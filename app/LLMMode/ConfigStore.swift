import Foundation

/// Reads and writes the CFG_* lines of ~/.llm-mode/config, which bin/llm-mode
/// `source`s as bash. Every other line is kept untouched.
struct ConfigStore {
    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".llm-mode/config")
    }

    let url: URL
    init(url: URL = ConfigStore.defaultURL) { self.url = url }

    /// Missing file reads as empty; any other read failure throws.
    private func readLines() throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let s = try String(contentsOf: url, encoding: .utf8)
        var ls = s.components(separatedBy: "\n")
        if ls.last == "" { ls.removeLast() }
        return ls
    }

    private func lines() -> [String] { (try? readLines()) ?? [] }

    private static func assignment(_ line: String) -> (key: String, raw: String)? {
        guard let m = line.firstMatch(of: /^(CFG_[A-Z_]+)=(.*)$/) else { return nil }
        return (String(m.1), String(m.2))
    }

    /// CFG_* values as bash would see them; later lines win, like `source`.
    func values() -> [String: String] {
        var v: [String: String] = [:]
        for line in lines() {
            if let a = Self.assignment(line) { v[a.key] = Self.unquote(a.raw) }
        }
        return v
    }

    /// true when the file has lines other than blanks, comments and CFG_ assignments
    func hasCustomLines() -> Bool {
        lines().contains { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && !t.hasPrefix("#") && Self.assignment(line) == nil
        }
    }

    /// Replaces the key's line in place (appends if missing); empty value removes it.
    func set(_ key: String, _ value: String) throws {
        let prefix = key + "="
        var out: [String] = []
        var written = false
        for line in try readLines() {
            guard line.hasPrefix(prefix) else { out.append(line); continue }
            if !written && !value.isEmpty { out.append(prefix + Self.quote(value)) }
            written = true
        }
        if !written && !value.isEmpty { out.append(prefix + Self.quote(value)) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let text = out.isEmpty ? "" : out.joined(separator: "\n") + "\n"
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    static func quote(_ v: String) -> String {
        "'" + v.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// One bash word: '…', "…" and \x quoting removed; stops at unquoted whitespace.
    static func unquote(_ raw: String) -> String {
        enum Mode { case plain, single, double }
        var mode = Mode.plain
        var out = ""
        var i = raw.startIndex
        while i < raw.endIndex {
            let c = raw[i]
            switch mode {
            case .plain:
                if c == " " || c == "\t" { return out }
                if c == "'" { mode = .single }
                else if c == "\"" { mode = .double }
                else if c == "\\" {
                    i = raw.index(after: i)
                    guard i < raw.endIndex else { return out }
                    out.append(raw[i])
                } else { out.append(c) }
            case .single:
                if c == "'" { mode = .plain } else { out.append(c) }
            case .double:
                let next = raw.index(after: i)
                if c == "\"" { mode = .plain }
                else if c == "\\", next < raw.endIndex, "\"\\$`".contains(raw[next]) {
                    i = next
                    out.append(raw[i])
                } else { out.append(c) }
            }
            i = raw.index(after: i)
        }
        return out
    }
}

/// CFG_WHITELIST_EXTRA as a list of bundle ids. bin/llm-mode greps bundle ids
/// (case-sensitive) with this regex, so the app stores ids, not display names.
enum Whitelist {
    /// mirrors the app-related part of WHITELIST_RE in bin/llm-mode
    static let builtIn = ["Terminal", "iTerm", "Finder"]
    private static let meta: Set<Character> = ["\\", "^", "$", ".", "|", "?", "*", "+", "(", ")", "[", "]", "{", "}"]

    static func escape(_ s: String) -> String {
        String(s.flatMap { meta.contains($0) ? ["\\", $0] : [$0] })
    }

    static func regex(from ids: [String]) -> String { ids.map(escape).joined(separator: "|") }

    /// nil when the regex is more than escaped literals joined by `|`
    static func ids(from regex: String) -> [String]? {
        if regex.isEmpty { return [] }
        var ids: [String] = []
        var cur = ""
        var escaped = false
        for ch in regex {
            if escaped {
                guard meta.contains(ch) else { return nil }
                cur.append(ch); escaped = false; continue
            }
            if ch == "\\" { escaped = true; continue }
            if ch == "|" {
                guard !cur.isEmpty else { return nil }
                ids.append(cur); cur = ""; continue
            }
            if meta.contains(ch) { return nil }
            cur.append(ch)
        }
        guard !escaped, !cur.isEmpty else { return nil }
        ids.append(cur)
        return ids
    }
}
