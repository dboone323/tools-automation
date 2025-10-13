class Calculator {
    add(a, b) {
        return a + b;
    }

    subtract(a, b) {
        return a - b;
    }

    multiply(a, b) {
        return a * b;
    }

    divide(a, b) {
        if (b === 0) {
            throw new Error("Division by zero");
        }
        return a / b;
    }

    power(base, exponent) {
        return Math.pow(base, exponent);
    }

    factorial(n) {
        if (n < 0) {
            throw new Error("Negative factorial");
        }
        return n === 0 ? 1 : n * this.factorial(n - 1);
    }

    fibonacci(n) {
        if (n < 0) {
            throw new Error("Negative fibonacci");
        }
        if (n <= 1) {
            return n;
        }
        return this.fibonacci(n - 1) + this.fibonacci(n - 2);
    }
}

module.exports = Calculator;
