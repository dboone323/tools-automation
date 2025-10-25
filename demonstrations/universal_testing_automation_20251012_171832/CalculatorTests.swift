@testable import Calculator
import XCTest

class CalculatorTests: XCTestCase {
    var calculator: Calculator!

    override func setUp() {
        super.setUp()
        calculator = Calculator()
    }

    override func tearDown() {
        calculator = nil
        super.tearDown()
    }

    func testAdd() {
        XCTAssertEqual(calculator.add(2, 3), 5)
        XCTAssertEqual(calculator.add(-1, 1), 0)
        XCTAssertEqual(calculator.add(0, 0), 0)
    }

    func testSubtract() {
        XCTAssertEqual(calculator.subtract(5, 3), 2)
        XCTAssertEqual(calculator.subtract(1, 1), 0)
        XCTAssertEqual(calculator.subtract(0, 5), -5)
    }

    func testMultiply() {
        XCTAssertEqual(calculator.multiply(2, 3), 6)
        XCTAssertEqual(calculator.multiply(-2, 3), -6)
        XCTAssertEqual(calculator.multiply(0, 5), 0)
    }

    func testDivide() throws {
        XCTAssertEqual(try calculator.divide(6, 3), 2)
        XCTAssertEqual(try calculator.divide(5, 2), 2.5)
        XCTAssertThrowsError(try calculator.divide(5, 0))
    }

    func testPower() {
        XCTAssertEqual(calculator.power(2, 3), 8)
        XCTAssertEqual(calculator.power(5, 0), 1)
        XCTAssertEqual(calculator.power(10, 1), 10)
    }

    func testFactorial() throws {
        XCTAssertEqual(try calculator.factorial(0), 1)
        XCTAssertEqual(try calculator.factorial(1), 1)
        XCTAssertEqual(try calculator.factorial(5), 120)
        XCTAssertThrowsError(try calculator.factorial(-1))
    }
}
