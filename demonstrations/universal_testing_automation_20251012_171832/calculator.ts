export class Calculator {
    add(a: number, b: number): number {
        return a + b;
    }

    subtract(a: number, b: number): number {
        return a - b;
    }

    multiply(a: number, b: number): number {
        return a * b;
    }

    divide(a: number, b: number): number {
        if (b === 0) {
            throw new Error("Division by zero");
        }
        return a / b;
    }

    power(base: number, exponent: number): number {
        return Math.pow(base, exponent);
    }

    factorial(n: number): number {
        if (n < 0) {
            throw new Error("Negative factorial");
        }
        return n === 0 ? 1 : n * this.factorial(n - 1);
    }

    fibonacci(n: number): number {
        if (n < 0) {
            throw new Error("Negative fibonacci");
        }
        if (n <= 1) {
            return n;
        }
        return this.fibonacci(n - 1) + this.fibonacci(n - 2);
    }
}

export class AdvancedCalculator extends Calculator {
    squareRoot(x: number): number {
        if (x < 0) {
            throw new Error("Negative square root");
        }
        return Math.sqrt(x);
    }

    logarithm(x: number, base: number = Math.E): number {
        if (x <= 0) {
            throw new Error("Non-positive logarithm");
        }
        return Math.log(x) / Math.log(base);
    }
}
