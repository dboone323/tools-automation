# New Developer Productivity Commands

These commands are integrated into the master controller to speed up quality and testing work.

## Generate XCTest skeletons from Swift sources
Writes test files to `Projects/<Project>/AutoTests/GeneratedTests_<YYYYMMDD>.swift`.

```bash
./Tools/Automation/master_automation.sh generate-tests               # all projects
./Tools/Automation/master_automation.sh generate-tests PlannerApp    # specific project
```

Notes:
- Generated tests are safe skeletons; add them to your Xcode Test target to run.
- The generator avoids Tests/AutoTests directories when scanning.

## Generate code health metrics JSON
Writes metrics to `Tools/Automation/metrics/code_health.json`.

```bash
./Tools/Automation/master_automation.sh code-health
```

Included metrics:
- Total Swift files and approximate lines
- Per-project Swift file counts, presence of tests/docs
- TODO/FIXME counts across the repo
- Last update timestamp

## File locations
- Generator: `Tools/Automation/ai_generate_swift_tests.py`
- Wrapper: `Tools/Automation/ai_generate_swift_tests.sh`
- Code Health: `Tools/Automation/code_health_dashboard.py`

## Troubleshooting
- Ensure `python3` is installed and available in the PATH.
- You can run the scripts directly with `python3` if needed.
- Test files are not automatically added to Xcode test targets; add them via Xcode.
