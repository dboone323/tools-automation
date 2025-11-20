# SwiftLint Guide

## Overview

This repository uses SwiftLint to enforce Swift style and conventions across all Swift projects. This guide explains how to use SwiftLint locally and how it integrates with our CI/CD pipeline.

## Table of Contents

- [Installation](#installation)
- [Running Locally](#running-locally)
- [Common Violations & Fixes](#common-violations--fixes)
- [CI Integration](#ci-integration)
- [IDE Integration](#ide-integration)
- [Configuration](#configuration)

---

## Installation

### macOS (Homebrew)

```bash
brew install swiftlint
```

### Verify Installation

```bash
swiftlint version
```

---

## Running Locally

### Lint a Single Project

```bash
cd MomentumFinance
swiftlint lint
```

### Lint with Auto-fix

SwiftLint can automatically fix some violations:

```bash
swiftlint lint --fix
```

⚠️ **Warning**: Always review auto-fixes before committing!

### Lint All Projects

From the repository root:

```bash
for project in MomentumFinance PlannerApp HabitQuest AvoidObstaclesGame CodingReviewer shared-kit; do
    echo "Linting $project..."
    cd $project && swiftlint lint --quiet && cd ..
done
```

---

## Common Violations & Fixes

### Large Tuple (> 2 members)

**Violation:**
```swift
private var data: (name: String, amount: Double, color: Color)
```

**Fix:** Create a custom struct
```swift
struct DataModel {
    let name: String
    let amount: Double
    let color: Color
}

private var data: DataModel
```

### Line Length (> 200 characters)

**Violation:**
```swift
let veryLongString = "This is an extremely long string that exceeds the maximum line length of 200 characters and needs to be broken up"
```

**Fix:** Break into multiple lines
```swift
let veryLongString = [
    "This is an extremely long string that exceeds",
    "the maximum line length and needs to be broken up"
].joined(separator: " ")
```

### Nesting (> 1 level deep)

**Violation:**
```swift
struct OuterStruct {
    struct MiddleStruct {
        struct InnerStruct {  // Too deeply nested
            let value: String
        }
    }
}
```

**Fix:** Move to file scope
```swift
struct InnerStruct {
    let value: String
}

struct MiddleStruct {
    let inner: InnerStruct
}

struct OuterStruct {
    let middle: MiddleStruct
}
```

### For-Where Loop

**Violation:**
```swift
for item in items {
    if item.isValid {
        process(item)
    }
}
```

**Fix:**
```swift
for item in items where item.isValid {
    process(item)
}
```

---

## CI Integration

### Workflow

SwiftLint runs automatically on:
- Every pull request to `main` or `develop`
- Every push to `main`

See [`.github/workflows/swiftlint.yml`](../.github/workflows/swiftlint.yml) for configuration.

### Matrix Strategy

The workflow runs SwiftLint for each Swift project in parallel:
- MomentumFinance
- PlannerApp
- HabitQuest
- AvoidObstaclesGame
- CodingReviewer
- shared-kit

### Results

- Violations are reported as GitHub annotations
- JSON results are uploaded as artifacts (retained for 30 days)
- The workflow uses `|| true` to not fail the build (warnings only)

---

## IDE Integration

### Xcode

SwiftLint integrates automatically with Xcode projects that have a Run Script build phase.

#### Add Build Phase

1. Open your Xcode project
2. Select your target → Build Phases
3. Click `+` → New Run Script Phase
4. Add this script:

```bash
if command -v swiftlint >/dev/null 2>&1
then
    swiftlint lint --config "${SRCROOT}/.swiftlint.yml"
else
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

5. Move the run script phase before "Compile Sources"

### VS Code

Install the [SwiftLint extension](https://marketplace.visualstudio.com/items?itemName=vknabel.vscode-swiftlint):

```bash
code --install-extension vknabel.vscode-swiftlint
```

---

## Configuration

Each Swift project can have its own `.swiftlint.yml` configuration file.

### Example Configuration

```yaml
# Disable specific rules
disabled_rules:
  - trailing_whitespace
  - todo

# Opt-in to additional rules
opt_in_rules:
  - empty_count
  - closure_spacing

# Configure rule thresholds
line_length:
  warning: 200
  error: 250

# Exclude files/folders
excluded:
  - Pods
  - .build
  - DerivedData
```

### Project-Specific Configs

- **MomentumFinance**: 48 warnings (24 nesting, 21 other)
- **PlannerApp**: 0 violations ✅
- **HabitQuest**: 0 violations ✅
- **AvoidObstaclesGame**: 0 violations ✅
- **CodingReviewer**: 0 violations ✅
- **shared-kit**: 0 violations ✅

---

## Pre-commit Hook (Optional)

Add a pre-commit hook to lint before committing:

```bash
# .git/hooks/pre-commit
#!/bin/bash

if command -v swiftlint >/dev/null 2>&1; then
    swiftlint lint --strict
else
    echo "warning: SwiftLint not installed"
    exit 0
fi
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

---

## Best Practices

1. **Fix violations incrementally** - Don't try to fix everything at once
2. **Use `--fix` carefully** - Always review auto-fixes
3. **Create custom structs** for large tuples - Improves code readability
4. **Keep lines under 200 characters** - Break long lines into multiple
5. **Avoid deep nesting** - Move nested types to file scope
6. **Use for-where** - More concise than for-if

---

## Getting Help

- [SwiftLint Documentation](https://realm.github.io/SwiftLint/)
- [SwiftLint Rules Reference](https://realm.github.io/SwiftLint/rule-directory.html)
- Check existing fixes in this repository for examples

---

## Status

**Current State:**
- ✅ 5 of 6 projects at 0 violations
- ⚠️ MomentumFinance: 48 warnings (down from 61)
- ✅ CI workflow active
- ✅ All serious violations resolved

**Progress:**
- 124 total violations fixed
- 6 large tuple violations fixed (PR #21)
- Remaining: 48 non-critical style warnings
