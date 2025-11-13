# Basic Usage Examples

## Python SDK Usage

```python
from tools_automation import ToolsAutomation

# Initialize client
client = ToolsAutomation(api_key='your-api-key')

# Basic operations
result = client.run_analysis('project-path')
print(f"Analysis complete: {result}")
```

## TypeScript SDK Usage

```typescript
import { ToolsAutomation } from 'tools-automation-sdk';

const client = new ToolsAutomation('your-api-key');
const result = await client.runAnalysis('project-path');
console.log(`Analysis complete: ${result}`);
```

## Go SDK Usage

```go
package main

import (
    "fmt"
    ta "github.com/tools-automation/go-sdk"
)

func main() {
    client := ta.NewClient("your-api-key")
    result, err := client.RunAnalysis("project-path")
    if err != nil {
        panic(err)
    }
    fmt.Printf("Analysis complete: %s\n", result)
}
```

## CLI Usage

```bash
# Install CLI
npm install -g @tools-automation/cli

# Run analysis
tools-automation analyze project-path

# Generate reports
tools-automation report --format json project-path
```
