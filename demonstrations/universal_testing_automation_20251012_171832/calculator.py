class Calculator:
    def add(self, a, b):
        return a + b

    def subtract(self, a, b):
        return a - b

    def multiply(self, a, b):
        return a * b

    def divide(self, a, b):
        if b == 0:
            raise ZeroDivisionError("Division by zero")
        return a / b

    def power(self, base, exponent):
        return base ** exponent

    def factorial(self, n):
        if n < 0:
            raise ValueError("Negative factorial")
        return 1 if n == 0 else n * self.factorial(n - 1)

    def fibonacci(self, n):
        if n < 0:
            raise ValueError("Negative fibonacci")
        if n <= 1:
            return n
        return self.fibonacci(n - 1) + self.fibonacci(n - 2)
