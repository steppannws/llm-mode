import XCTest
@testable import LLMMode

final class StatusTests: XCTestCase {
    let fixture = #"{"backend":"lmstudio","model":"qwen3","port":1234,"server":"up","host":"mac.local","mode":"on","started_at":1000,"mem":{"total_mb":24576,"wired_limit_mb":20480,"reserve_mb":4096,"model_mb":17408,"free_mb":2048},"backends":{"lmstudio":true,"ollama":false,"llamacpp":true,"mlx":false}}"#

    func testDecodesFixture() throws {
        let s = try Status.decode(Data(fixture.utf8))
        XCTAssertEqual(s.backend, "lmstudio")
        XCTAssertTrue(s.serverUp)
        XCTAssertTrue(s.isOn)
        XCTAssertEqual(s.startedAt, 1000)
        XCTAssertEqual(s.mem.wiredLimitMb, 20480)
        XCTAssertEqual(s.backends["llamacpp"], true)
    }

    func testDecodesNulls() throws {
        let json = fixture
            .replacingOccurrences(of: #""backend":"lmstudio""#, with: #""backend":null"#)
            .replacingOccurrences(of: #""model":"qwen3""#, with: #""model":null"#)
            .replacingOccurrences(of: #""started_at":1000"#, with: #""started_at":null"#)
            .replacingOccurrences(of: #""mode":"on""#, with: #""mode":"off""#)
        let s = try Status.decode(Data(json.utf8))
        XCTAssertNil(s.backend)
        XCTAssertNil(s.startedAt)
        XCTAssertFalse(s.isOn)
    }

    func testSegmentsClampOtherAtZero() {
        let m = Status.Mem(totalMb: 24576, wiredLimitMb: 20480, reserveMb: 4096, modelMb: 17408, freeMb: 2048)
        XCTAssertEqual(m.segments.other, 1024)
        let over = Status.Mem(totalMb: 8192, wiredLimitMb: 4096, reserveMb: 4096, modelMb: 4096, freeMb: 4096)
        XCTAssertEqual(over.segments.other, 0)
    }

    func testFormat() {
        XCTAssertEqual(Format.gb(17408), "17")
        XCTAssertEqual(Format.gb(5256), "5.1")
        XCTAssertEqual(Format.gb(0), "0")
        let now = Date(timeIntervalSince1970: 1000 + 72 * 60)
        XCTAssertEqual(Format.uptime(from: 1000, now: now), "1h 12m")
        XCTAssertEqual(Format.uptime(from: 1000, now: Date(timeIntervalSince1970: 1000 + 300)), "5m")
        XCTAssertEqual(Format.uptime(from: 1000, now: Date(timeIntervalSince1970: 1000 + 2 * 86400 + 3 * 3600)), "2d 3h")
        XCTAssertEqual(Format.uptime(from: 2000, now: Date(timeIntervalSince1970: 1000)), "0m")
        XCTAssertEqual(Format.backendName("llamacpp"), "llama.cpp")
        XCTAssertEqual(Format.backendName(nil), "No backend")
        XCTAssertEqual(Format.quitSummary(["A", "B"]), "A, B")
        XCTAssertEqual(Format.quitSummary(["A", "B", "C", "D", "E", "F"]), "A, B, C, D +2 more")
        XCTAssertEqual(Format.lastLine("warn\n{\"x\":1}\n\n"), "{\"x\":1}")
    }

    @MainActor
    func testApplySetsStatusAndClearsError() {
        let m = StatusModel()
        m.error = "old"
        m.apply(code: 0, out: fixture + "\n")
        XCTAssertEqual(m.status?.model, "qwen3")
        XCTAssertNil(m.error)
    }

    @MainActor
    func testApplyMapsUsageToTooOldMessage() {
        let m = StatusModel()
        m.apply(code: 2, out: "usage: llm-mode {on|off|status|serve-stop} [--dry-run] [--relaunch]\n")
        XCTAssertEqual(m.error, "llm-mode CLI is too old for this app — run install.sh")
    }

    @MainActor
    func testApplyKeepsMissingCliMessage() {
        let m = StatusModel()
        m.apply(code: 127, out: StatusModel.missingCLI)
        XCTAssertEqual(m.error, StatusModel.missingCLI)
    }
}
