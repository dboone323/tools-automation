// Simple agent matcher for testing
function matchAgent(task) {
  if (!task || !task.type) {
    return 'agent_default';
  }

  switch (task.type) {
    case 'code_improvement':
      return 'agent_codegen';
    case 'system_monitoring':
      return 'agent_monitoring';
    case 'documentation':
      return 'agent_docs';
    default:
      return 'agent_default';
  }
}

module.exports = { matchAgent };