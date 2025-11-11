#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script to create the `quantum-workspace` meta-repo with pinned submodules.
# Requirements: gh (GitHub CLI), git, network access. Run from any working directory.

# Background mode and autorestart
BACKGROUND_MODE="${BACKGROUND_MODE:-false}"
UPDATE_INTERVAL="${UPDATE_INTERVAL:-86400}" # 24 hours default
MAX_RESTARTS="${MAX_RESTARTS:-3}"

ORG="dboone323"
META_REPO="quantum-workspace"
APPS=("coding-reviewer" "planner-app" "avoid-obstacles-game" "momentum-finance" "habit-quest")
INFRA=("shared-kit" "tools-automation")

# Tags to pin (adjust as needed)
# For apps, default to v1.0.0-alpha.1. For libs/tools, v1.0.0.
declare -A TAGS=(
    ["coding-reviewer"]="v1.0.0-alpha.1"
    ["planner-app"]="v1.0.0-alpha.1"
    ["avoid-obstacles-game"]="v1.0.0-alpha.1"
    ["momentum-finance"]="v1.0.0-alpha.1"
    ["habit-quest"]="v1.0.0-alpha.1"
    ["shared-kit"]="v1.0.0"
    ["tools-automation"]="v1.0.0"
)

# Allow overriding local directory and remote repo name via env vars
META_REPO_LOCAL="${META_REPO_LOCAL:-${META_REPO}}"
META_REPO_REMOTE="${META_REPO_REMOTE:-${META_REPO}}"

REPO_DIR="${PWD}/${META_REPO_LOCAL}"

# Function to bootstrap/create meta-repo
bootstrap_repo() {
    if [ -d "${REPO_DIR}" ]; then
        echo "Directory ${REPO_DIR} already exists. Checking for updates instead of bootstrap..."
        update_submodules
        return 0
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
}

# Function to update submodules
update_submodules() {
    if [ ! -d "${REPO_DIR}" ]; then
        echo "Meta-repo directory ${REPO_DIR} does not exist. Run bootstrap first."
        return 1
    fi

    cd "${REPO_DIR}"
    echo "Updating submodules in ${REPO_DIR}..."

    # Check if there are uncommitted changes that would prevent update
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Warning: Uncommitted changes detected in meta-repo. Skipping submodule update to avoid conflicts."
        echo "Please commit or stash your changes before running updates."
        return 1
    fi

    # Update all submodules
    if ! git submodule update --remote --merge; then
        echo "Warning: Submodule update failed. This may be due to local changes in submodules."
        echo "Please check individual submodules for conflicts."
        return 1
    fi

    # Check for new tags and update if needed
    for name in "${APPS[@]}" "${INFRA[@]}"; do
        if [ -d "${name}" ]; then
            cd "${name}"

            # Check if submodule has uncommitted changes
            if ! git diff --quiet || ! git diff --cached --quiet; then
                echo "Warning: Uncommitted changes in ${name} submodule, skipping tag update"
                cd ..
                continue
            fi

            git fetch --tags

            current_tag="${TAGS[$name]:-main}"
            if git tag | grep -q "^${current_tag}$"; then
                echo "Updating ${name} to tag ${current_tag}"
                git checkout "${current_tag}"
                cd ..
                git add "${name}"
            else
                echo "Tag ${current_tag} not found for ${name}, staying on current branch"
                cd ..
            fi
        fi
    done

    # Commit if there are changes
    if git diff --cached --quiet; then
        echo "No submodule updates needed"
    else
        git commit -m "chore: update submodules to latest tags"
        git push origin main
        echo "Submodules updated and pushed"
    fi
}

# Main execution
if [[ "$BACKGROUND_MODE" == "true" ]]; then
    echo "Starting meta-repo bootstrap service in background mode (interval: ${UPDATE_INTERVAL}s)"

    restart_count=0
    while [[ $restart_count -lt $MAX_RESTARTS ]]; do
        echo "Bootstrap cycle $((restart_count + 1))/$MAX_RESTARTS started at $(date)"

        if bootstrap_repo; then
            echo "Bootstrap/update completed successfully"
            restart_count=0 # Reset on success
        else
            echo "Bootstrap/update failed, will retry"
            restart_count=$((restart_count + 1))
            sleep 60 # Wait before retry
            continue
        fi

        echo "Sleeping for ${UPDATE_INTERVAL} seconds..."
        sleep "$UPDATE_INTERVAL"
    done

    echo "Maximum restart attempts reached, stopping bootstrap service"
    exit 1
else
    bootstrap_repo
fi
