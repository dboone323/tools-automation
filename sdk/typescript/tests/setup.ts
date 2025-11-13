// Test setup file
import { jest } from '@jest/globals';

// Create a proper axios mock with all required properties
const mockAxios = {
  create: jest.fn(() => ({
    interceptors: {
      response: {
        use: jest.fn(),
      },
    },
    request: jest.fn(),
  })),
  get: jest.fn(),
  post: jest.fn(),
  put: jest.fn(),
  delete: jest.fn(),
} as any;

// Mock axios for all tests
jest.mock('axios', () => mockAxios);

// Set up global test utilities
global.console = {
  ...console,
  // Uncomment to suppress console logs during tests
  // log: jest.fn(),
  // error: jest.fn(),
  // warn: jest.fn(),
};

// Export for use in tests
export { mockAxios };