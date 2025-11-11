const { matchAgent } = require('../../agentMatcher');

describe('Agent Matcher', () => {
  test('matches codegen tasks correctly', () => {
    const task = { type: 'code_improvement', priority: 'high' };
    expect(matchAgent(task)).toBe('agent_codegen');
  });
});
