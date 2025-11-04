#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script to create the `quantum-workspace` meta-repo with pinned submodules.
# Requirements: gh (GitHub CLI), git, network access. Run from any working directory.

ORG="dboone323"
META_REPO="quantum-workspace"
APPS=("coding-reviewer" "planner-app" "avoid-obstacles-game" "momentum-finance" "habit-quest")
INFRA=("shared-kit" "tools-automation")

# Tags to pin (adjust as needed)
# For apps, default to v1.0.0-alpha.1. For libs/tools, v1.0.0.
declare -A TAGS=(
    [coding - reviewer]="v1.0.0-alpha.1"
    [planner - app]="v1.0.0-alpha.1"
    [avoid - obstacles - game]="v1.0.0-alpha.1"
    [momentum - finance]="v1.0.0-alpha.1"
    [habit - quest]="v1.0.0-alpha.1"
    [shared - kit]="v1.0.0"
    [tools - automation]="v1.0.0"
)

# Allow overriding local directory and remote repo name via env vars
META_REPO_LOCAL="${META_REPO_LOCAL:-${META_REPO}}"
META_REPO_REMOTE="${META_REPO_REMOTE:-${META_REPO}}"

REPO_DIR="${PWD}/${META_REPO_LOCAL}"

if [ -d "${REPO_DIR}" ]; then
    echo "Directory ${REPO_DIR} already exists. Exiting to avoid overwrite." >&2
    exit 1
fi

echo "Creating meta-repo local dir '${META_REPO_LOCAL}' (remote: ${ORG}/${META_REPO_REMOTE})..."
mkdir -p "${REPO_DIR}"
cd "${REPO_DIR}"

git init

echo "Adding submodules..."
for name in "${APPS[@]}" "${INFRA[@]}"; do
    url="https://github.com/${ORG}/${name}.git"
    echo "  - ${name} from ${url}"
    git submodule add "${url}" "${name}"
    (cd "${name}" && git fetch --tags && git checkout "${TAGS[$name]:-main}")
    git add "${name}"
done

git commit -m "feat: initial meta-repo with submodules pinned to tags"

echo "Creating GitHub repo (public) if missing..."
if gh repo view "${ORG}/${META_REPO_REMOTE}" >/dev/null 2>&1; then
    echo "Repo ${ORG}/${META_REPO_REMOTE} already exists on GitHub. Skipping creation."
else
    gh repo create "${ORG}/${META_REPO_REMOTE}" --public --source=. --remote=origin
fi

echo "Setting remote and pushing to GitHub..."
branch="main"
git branch -M "$branch"
if git remote get-url origin >/dev/null 2>&1; then
    echo "Origin remote already set: $(git remote get-url origin)"
else
    git remote add origin "https://github.com/${ORG}/${META_REPO_REMOTE}.git"
fi
git push -u origin "$branch"

echo "Done. Meta-repo available at https://github.com/${ORG}/${META_REPO_REMOTE}"
