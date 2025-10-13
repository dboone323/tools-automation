import Foundation

class Calculator {
    func add(_ a: Double, _ b: Double) -> Double {
        return a + b
    }

    func subtract(_ a: Double, _ b: Double) -> Double {
        return a - b
    }

    func multiply(_ a: Double, _ b: Double) -> Double {
        return a * b
    }

    func divide(_ a: Double, _ b: Double) throws -> Double {
        guard b != 0 else {
            throw CalculatorError.divisionByZero
        }
        return a / b
    }

    func power(_ base: Double, _ exponent: Int) -> Double {
        return pow(base, Double(exponent))
    }

    func factorial(_ n: Int) throws -> Int {
        guard n >= 0 else {
            throw CalculatorError.negativeFactorial
        }
        return n == 0 ? 1 : n * (try factorial(n - 1))
    }
}

enum CalculatorError: Error {
    case divisionByZero
    case negativeFactorial
}
