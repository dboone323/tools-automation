const Calculator = require('./calculator');

describe('Calculator', () => {
    let calculator;

    beforeEach(() => {
        calculator = new Calculator();
    });

    describe('add', () => {
        it('should add two positive numbers', () => {
            expect(calculator.add(2, 3)).toBe(5);
        });

        it('should add negative and positive numbers', () => {
            expect(calculator.add(-1, 1)).toBe(0);
        });

        it('should add zeros', () => {
            expect(calculator.add(0, 0)).toBe(0);
        });
    });

    describe('subtract', () => {
        it('should subtract two numbers', () => {
            expect(calculator.subtract(5, 3)).toBe(2);
        });

        it('should subtract equal numbers', () => {
            expect(calculator.subtract(1, 1)).toBe(0);
        });

        it('should subtract from zero', () => {
            expect(calculator.subtract(0, 5)).toBe(-5);
        });
    });

    describe('multiply', () => {
        it('should multiply two numbers', () => {
            expect(calculator.multiply(2, 3)).toBe(6);
        });

        it('should multiply negative numbers', () => {
            expect(calculator.multiply(-2, 3)).toBe(-6);
        });

        it('should multiply by zero', () => {
            expect(calculator.multiply(0, 5)).toBe(0);
        });
    });

    describe('divide', () => {
        it('should divide two numbers', () => {
            expect(calculator.divide(6, 3)).toBe(2);
        });

        it('should divide with remainder', () => {
            expect(calculator.divide(5, 2)).toBe(2.5);
        });

        it('should throw error for division by zero', () => {
            expect(() => calculator.divide(5, 0)).toThrow('Division by zero');
        });
    });

    describe('power', () => {
        it('should calculate power', () => {
            expect(calculator.power(2, 3)).toBe(8);
        });

        it('should handle zero exponent', () => {
            expect(calculator.power(5, 0)).toBe(1);
        });
    });

    describe('factorial', () => {
        it('should calculate factorial of zero', () => {
            expect(calculator.factorial(0)).toBe(1);
        });

        it('should calculate factorial of positive number', () => {
            expect(calculator.factorial(5)).toBe(120);
        });

        it('should throw error for negative factorial', () => {
            expect(() => calculator.factorial(-1)).toThrow('Negative factorial');
        });
    });

    describe('fibonacci', () => {
        it('should calculate fibonacci of zero', () => {
            expect(calculator.fibonacci(0)).toBe(0);
        });

        it('should calculate fibonacci of one', () => {
            expect(calculator.fibonacci(1)).toBe(1);
        });

        it('should calculate fibonacci of five', () => {
            expect(calculator.fibonacci(5)).toBe(5);
        });

        it('should throw error for negative fibonacci', () => {
            expect(() => calculator.fibonacci(-1)).toThrow('Negative fibonacci');
        });
    });
});
