import unittest
from calculator import Calculator


class TestCalculator(unittest.TestCase):
    def setUp(self):
        self.calculator = Calculator()

    def test_add(self):
        self.assertEqual(self.calculator.add(2, 3), 5)
        self.assertEqual(self.calculator.add(-1, 1), 0)
        self.assertEqual(self.calculator.add(0, 0), 0)

    def test_subtract(self):
        self.assertEqual(self.calculator.subtract(5, 3), 2)
        self.assertEqual(self.calculator.subtract(1, 1), 0)
        self.assertEqual(self.calculator.subtract(0, 5), -5)

    def test_multiply(self):
        self.assertEqual(self.calculator.multiply(2, 3), 6)
        self.assertEqual(self.calculator.multiply(-2, 3), -6)
        self.assertEqual(self.calculator.multiply(0, 5), 0)

    def test_divide(self):
        self.assertEqual(self.calculator.divide(6, 3), 2)
        self.assertEqual(self.calculator.divide(5, 2), 2.5)
        with self.assertRaises(ZeroDivisionError):
            self.calculator.divide(5, 0)

    def test_power(self):
        self.assertEqual(self.calculator.power(2, 3), 8)
        self.assertEqual(self.calculator.power(5, 0), 1)
        self.assertEqual(self.calculator.power(10, 1), 10)

    def test_factorial(self):
        self.assertEqual(self.calculator.factorial(0), 1)
        self.assertEqual(self.calculator.factorial(1), 1)
        self.assertEqual(self.calculator.factorial(5), 120)
        with self.assertRaises(ValueError):
            self.calculator.factorial(-1)

    def test_fibonacci(self):
        self.assertEqual(self.calculator.fibonacci(0), 0)
        self.assertEqual(self.calculator.fibonacci(1), 1)
        self.assertEqual(self.calculator.fibonacci(5), 5)
        with self.assertRaises(ValueError):
            self.calculator.fibonacci(-1)
