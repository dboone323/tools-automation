# Linting Guide for Tools-Automation

## Overview

This repository uses automated linting to maintain code quality across multiple languages and projects. All code must pass linting checks before being merged.

## SwiftLint (Swift Projects)

### Installation

**macOS (Homebrew):**
```bash
brew install swiftlint
```

**Verify installation:**
```bash
swiftlint version
```

### Usage

**Lint a specific project:**
```bash
cd PlannerApp  # or MomentumFinance, HabitQuest, etc.
swiftlint
```

**Auto-fix violations:**
```bash
swiftlint --fix
```

**Generate detailed report:**
```bash
swiftlint lint --reporter json > lint-report.json
```

### Configuration

Each Swift project may have a `.swiftlint.yml` configuration file. The default rules enforced:
- No serious violations (errors) allowed
- Style violations (warnings) noted but non-blocking for most projects
- Exception: MomentumFinance has 54 known warnings being addressed

### Common Violations & Fixes

**1. Large Tuple (> 2 members)**
```swift
// ❌ Before
func getData() -> (String, Int, Bool) { ... }

// ✅ After
struct DataResult {
    let name: String
    let count: Int
    let isValid: Bool
}
func getData() -> DataResult { ... }
```

**2. Nesting Violation (> 1 level deep)**
```swift
// ❌ Before
class Manager {
    struct Config {
        enum Type { case a, b }  // Too nested!
    }
}

// ✅ After
enum ConfigType { case a, b }
class Manager {
    struct Config {
        let type: ConfigType
    }
}
```

**3. For-Where Preferred**
```swift
// ❌ Before
for item in items {
    if condition {
        process(item)
    }
}

// ✅ After
for item in items where condition {
    process(item)
}
```

**4. Closure Parameter Position**
```swift
// ❌ Before
.map {
    item in
    process(item)
}

// ✅ After
.map { item in
    process(item)
}
```

### IDE Integration

**Xcode:**
1. Add Run Script Phase to Build Phases
2. Script: `if which swiftlint >/dev/null; then swiftlint; fi`
3. Run script on every build for immediate feedback

**VS Code:**
- Install "SwiftLint" extension
- Linting runs automatically on save

---

## Shellcheck (Shell Scripts)

### Installation

**macOS:**
```bash
brew install shellcheck
```

**Ubuntu/Debian:**
```bash
sudo apt-get install shellcheck
```

### Usage

**Check a script:**
```bash
shellcheck scripts/my_script.sh
```

**Check all scripts:**
```bash
find scripts -name "*.sh" -exec shellcheck {} \;
```

### Common Issues

**SC2086: Quote variables**
```bash
# ❌ Before
echo $MY_VAR

# ✅ After
echo "$MY_VAR"
```

**SC2155: Separate declaration and assignment**
```bash
# ❌ Before
local result=$(command)

# ✅ After
local result
result=$(command)
```

---

## CI/CD Integration

### Automated Checks

All linting is automated via GitHub Actions:

**SwiftLint Workflow:**
- Runs on every PR and push to main
- Checks all 6 Swift projects in parallel
- **Fails** if serious violations found
- **Warns** on style violations
- Reports uploaded as artifacts

**PR Validation:**
- Shellcheck on all `.sh` files
- Python syntax validation
- Quick Swift lint check
- YAML/workflow validation

### Pull Request Requirements

Before your PR can be merged:
1. ✅ All SwiftLint serious violations must be resolved
2. ✅ Shellcheck must pass for all scripts
3. ⚠️ Style warnings should be addressed (but won't block merge)

---

## Pre-Commit Hooks

### Setup

Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash

echo "Running pre-commit linting..."

# SwiftLint for Swift files
SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep ".swift$")
if [ -n "$SWIFT_FILES" ]; then
    if which swiftlint >/dev/null; then
        echo "Running SwiftLint..."
        swiftlint lint --quiet || {
            echo "❌ SwiftLint found violations. Fix them before committing."
            exit 1
        }
    fi
fi

# Shellcheck for shell scripts
SHELL_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep ".sh$")
if [ -n "$SHELL_FILES" ]; then
    if which shellcheck >/dev/null; then
        echo "Running Shellcheck..."
        for file in $SHELL_FILES; do
            shellcheck "$file" || {
                echo "❌ Shellcheck found violations in $file"
                exit 1
            }
        done
    fi
fi

echo "✅ All linting checks passed!"
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

---

## Project-Specific Status

| Project | SwiftLint Status | Notes |
|---------|-----------------|-------|
| **PlannerApp** | ✅ 0 violations | Perfect |
| **CodingReviewer** | ✅ 0 violations | Perfect |
| **HabitQuest** | ✅ 0 violations | Perfect |
| **AvoidObstaclesGame** | ✅ 0 violations | Perfect |
| **shared-kit** | ✅ 0 violations | Perfect |
| **MomentumFinance** | ⚠️ 54 warnings | Being addressed in follow-up PR |

---

## Troubleshooting

**"swiftlint: command not found"**
- Install via Homebrew: `brew install swiftlint`
- Ensure `/opt/homebrew/bin` is in your PATH

**"Too many violations"**
- Run `swiftlint --fix` to auto-fix simple issues
- Address remaining violations manually
- See examples above for common fixes

**CI failing but local linting passes**
- Ensure you have latest swiftlint version
- Check that all submodules are updated
- Review CI logs for specific file/line numbers

---

## Getting Help

- **SwiftLint docs:** https://realm.github.io/SwiftLint/
- **Shellcheck wiki:** https://www.shellcheck.net/
- **Internal:** Check `implementation_plan.md` for detailed strategies

---

## Version History

- **2025-11-19:** Initial linting guide created
- **2025-11-19:** SwiftLint CI integration added
- **2025-11-19:** Completed comprehensive audit (124 violations fixed)
