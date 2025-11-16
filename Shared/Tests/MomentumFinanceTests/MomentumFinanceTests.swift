import XCTest
@testable import Shared

final class MomentumFinanceTests: XCTestCase {
    func testSharedHello() {
        XCTAssertEqual(Shared.hello(), "Shared")
    }
}
