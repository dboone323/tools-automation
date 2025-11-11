module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/unit/**/*.js', '**/?(*.)+(spec|test).js'],
  testPathIgnorePatterns: ['tests/e2e', 'node_modules'],
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  verbose: true,
};
