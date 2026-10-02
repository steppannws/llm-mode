import XCTest
@testable import LLMMode

@MainActor
final class ConfigModelTests: XCTestCase {
    func testSetWritesOnlyOnChangeAndReloads() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "/config")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let m = ConfigModel(store: ConfigStore(url: url))
        m.reload()
        XCTAssertEqual(m.value("CFG_PORT"), "")
        m.set("CFG_PORT", "")          // unchanged: must not create the file
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        m.set("CFG_PORT", "8080")
        XCTAssertEqual(m.value("CFG_PORT"), "8080")
        XCTAssertNil(m.saveError)
    }

    func testInitLoadsExistingValues() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("config")
        try "CFG_PORT=9999\n".write(to: url, atomically: true, encoding: .utf8)
        let m = ConfigModel(store: ConfigStore(url: url))   // no explicit reload()
        XCTAssertEqual(m.value("CFG_PORT"), "9999")
    }
}
