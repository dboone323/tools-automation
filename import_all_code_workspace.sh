#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT=$(pwd -P)
TS=20250826T130522Z
IMPORT_BRANCH=import/code-workspace/snapshot-${TS}

# Create import branch
if git show-ref --verify --quiet refs/heads/"${IMPORT_BRANCH}"; then
	git checkout "${IMPORT_BRANCH}"
else
	git checkout -b "${IMPORT_BRANCH}"
fi

mkdir -p Projects Shared Tools/Imported Documentation Automation/IMPORTS

# Copy Projects
rsync -a --exclude='.git' --exclude='BuildData_*' --exclude='*.xcuserdata' --exclude='DerivedData' --prune-empty-dirs \
	/Users/danielstevens/Desktop/Code/Projects/ Projects/

# Copy Shared
rsync -a --exclude='.git' /Users/danielstevens/Desktop/Code/Shared/ Shared/

# Copy Tools (Automation separately)
rsync -a --exclude='.git' /Users/danielstevens/Desktop/Code/Tools/Automation/ Automation/IMPORTS/Tools_snapshot_"${TS}"/
rsync -a --exclude='.git' /Users/danielstevens/Desktop/Code/Tools/ Tools/Imported/Tools_snapshot_"${TS}"/

# Copy Documentation
rsync -a --exclude='.git' /Users/danielstevens/Desktop/Code/Documentation/ Documentation/Imported_CodeWorkspace_"${TS}"/

# Copy CodingReviewer-Modular
rsync -a --exclude='.git' /Users/danielstevens/Desktop/CodingReviewer-Modular/ Projects/CodingReviewer-Modular/

# Show staged candidate changes
echo "Copy complete. Run 'git add' to stage what you want or I can add everything and commit for you."

git status --porcelain | sed -n '1,200p'
