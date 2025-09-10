Summary

File: Core/Services/GameRules.swift
Issue: Identifier Name Violations: short names like `i` and `xp` flagged. `xp` may be domain-specific and acceptable, but `i` should be clarified.

Suggested renames:

- i -> itemIndex or index
- xp -> experiencePoints (if used across codebase) or xp (if domain term commonly used)

Rationale: `i` is ambiguous; `xp` is domain-specific but should be consistent across the repo. Choosing longer names improves readability and resolves linter errors.

Patch guidance

- Replace local occurrences of `i` with `itemIndex` or `index` depending on context.
- Keep `xp` if it's a well-known domain token; otherwise expand to `experiencePoints`.

Priority: Medium

Reviewer instructions
- Confirm `xp` meaning across codebase (search for `xp` occurrences) and standardize accordingly.
- Run unit tests and check game calculations produce identical outputs.
