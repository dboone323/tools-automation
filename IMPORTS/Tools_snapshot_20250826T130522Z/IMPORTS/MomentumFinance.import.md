# Import metadata: MomentumFinance

source_path: /Users/danielstevens/Desktop/Code/Projects/MomentumFinance
snapshot_branch: snapshot/20250826T130522Z
import_branch: import/MomentumFinance/snapshot-20250826T130522Z
target_repo: dboone323/Quantum-workspace
target_subdir: Projects/MomentumFinance
preserve_history: false
notes: |
This import is snapshot-only. The contents will be copied under `Tools/Projects/` for review.
Place all automation/tooling files under `Tools/Automation/` before final merge.

# PR template

pr_title: "[import][snapshot] MomentumFinance → Projects/MomentumFinance (snapshot 20250826T130522Z)"
pr_body: |
Automated import of local snapshot for review. This is non-destructive and preserves a snapshot in `import/MomentumFinance/snapshot-20250826T130522Z`.
Reviewers: github-copilot (attempt autofix), then dboone323.

See logs: Tools/Automation/logs/force_snapshot_20250826T130522Z/MomentumFinance_snapshot.log

action: create_branch_and_copy_snapshot
