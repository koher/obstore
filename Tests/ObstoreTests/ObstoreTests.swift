import XCTest
@testable import Obstore

final class ObstoreTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Obstore().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
