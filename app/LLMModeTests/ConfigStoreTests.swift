import XCTest
@testable import LLMMode

final class ConfigStoreTests: XCTestCase {
    var dir: URL!
    var url: URL { dir.appendingPathComponent("sub/config") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func write(_ s: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try s.write(to: url, atomically: true, encoding: .utf8)
    }
    func read() throws -> String { try String(contentsOf: url, encoding: .utf8) }

    func testValuesStripsQuotingAndTrailingComments() throws {
        try write("""
        # my config
        CFG_PORT=1234  # default
        CFG_MODEL='it'\\''s $HOME'
        CFG_BACKEND="oll\\"ama"

        """)
        let v = ConfigStore(url: url).values()
        XCTAssertEqual(v["CFG_PORT"], "1234")
        XCTAssertEqual(v["CFG_MODEL"], "it's $HOME")
        XCTAssertEqual(v["CFG_BACKEND"], "oll\"ama")
    }

    func testMissingFileHasNoValues() {
        XCTAssertEqual(ConfigStore(url: url).values(), [:])
        XCTAssertFalse(ConfigStore(url: url).hasCustomLines())
    }

    func testCustomLinesDetected() throws {
        try write("# c\nCFG_PORT=1\n")
        XCTAssertFalse(ConfigStore(url: url).hasCustomLines())
        try write("CFG_PORT=1\nif true; then CFG_MODEL=x; fi\n")
        XCTAssertTrue(ConfigStore(url: url).hasCustomLines())
    }

    func testSetReplacesInPlaceAndKeepsOtherLines() throws {
        try write("# head\nCFG_PORT=1234\nexport FOO=1\nCFG_MODEL=a\n")
        try ConfigStore(url: url).set("CFG_PORT", "8080")
        XCTAssertEqual(try read(), "# head\nCFG_PORT='8080'\nexport FOO=1\nCFG_MODEL=a\n")
    }

    func testSetAppendsMissingKeyAndCreatesFile() throws {
        try ConfigStore(url: url).set("CFG_MODEL", "it's")
        XCTAssertEqual(try read(), "CFG_MODEL='it'\\''s'\n")
    }

    func testSetEmptyRemovesAllCopiesOfKey() throws {
        try write("CFG_PORT=1\n# keep\nCFG_PORT=2\n")
        try ConfigStore(url: url).set("CFG_PORT", "")
        XCTAssertEqual(try read(), "# keep\n")
    }

    func testQuoteRoundTrip() {
        for s in ["plain", "it's", "a b", "$(rm -rf ~)", "\"q\"", "back\\slash", "''", ""] {
            XCTAssertEqual(ConfigStore.unquote(ConfigStore.quote(s)), s, s)
        }
        XCTAssertEqual(ConfigStore.quote("it's"), "'it'\\''s'")
    }

    func testSetThrowsAndPreservesUnreadableFile() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data([0x43, 0x46, 0x47, 0x5F, 0x58, 0x3D, 0xFF, 0xFE, 0x0A])
        try bytes.write(to: url)
        XCTAssertThrowsError(try ConfigStore(url: url).set("CFG_PORT", "1"))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
}
