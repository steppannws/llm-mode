import XCTest
@testable import LLMMode

final class WhitelistTests: XCTestCase {
    func testRegexEscapesBundleIds() {
        XCTAssertEqual(Whitelist.regex(from: ["com.spotify.client", "com.mitchellh.ghostty"]),
                       "com\\.spotify\\.client|com\\.mitchellh\\.ghostty")
        XCTAssertEqual(Whitelist.regex(from: []), "")
    }

    func testIdsParsesWhatRegexBuilds() {
        let ids = ["com.spotify.client", "Ghostty", "a+b(c)"]
        XCTAssertEqual(Whitelist.ids(from: Whitelist.regex(from: ids)), ids)
        XCTAssertEqual(Whitelist.ids(from: ""), [])
        XCTAssertEqual(Whitelist.ids(from: "Ghostty|com\\.mitchellh\\.ghostty"), ["Ghostty", "com.mitchellh.ghostty"])
    }

    func testIdsReturnsNilForRealRegex() {
        XCTAssertNil(Whitelist.ids(from: "com\\.foo.*"))
        XCTAssertNil(Whitelist.ids(from: "a||b"))
        XCTAssertNil(Whitelist.ids(from: "^Slack$"))
        XCTAssertNil(Whitelist.ids(from: "trailing\\"))
        XCTAssertNil(Whitelist.ids(from: "foo\\dbar"))
        XCTAssertNil(Whitelist.ids(from: "Ghostty|com\\.foo.*"))
    }
}
