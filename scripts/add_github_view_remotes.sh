#!/usr/bin/env bash
# Add a "view" remote for a list of repos owned by a user, pointing to the
# public https://github.com/<user>/<repo>.git URL. This is helpful when you
# have many repositories locally and want quick read-only remotes for viewing.
# Usage:
#   bash scripts/add_github_view_remotes.sh --dry-run
#   bash scripts/add_github_view_remotes.sh
#   bash scripts/add_github_view_remotes.sh --open  # opens the repos in a browser
#   bash scripts/add_github_view_remotes.sh --clone-if-missing  # clones missing repos first
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REPO_NAME="$(basename "${REPO_ROOT}")"
BASE_USER=dboone323
# repo list to add 'view' remotes for (directory names)
REPOS=(
    tools-automation
    shared-kit
    CodingReviewer
    PlannerApp
    HabitQuest
    MomentumFinance
    AvoidObstaclesGame
)
# Map directory names to GitHub repo names
get_github_name() {
    case "$1" in
    tools-automation) echo tools-automation ;;
    shared-kit) echo shared-kit ;;
    CodingReviewer) echo coding-reviewer ;;
    PlannerApp) echo planner-app ;;
    HabitQuest) echo habitquest ;;
    MomentumFinance) echo momentum-finance ;;
    AvoidObstaclesGame) echo avoid-obstacles-game ;;
    *) echo "$1" ;; # fallback
    esac
}

DRY_RUN=0
OPEN=0
CLONE_MISSING=0

# Parse flags
function usage() {
    echo "Usage: $0 [--user USER] [--dry-run] [--open] [--clone-if-missing]" >&2
}

while [[ ${#} -gt 0 ]]; do
    case "$1" in
    --dry-run)
        DRY_RUN=1
        shift
        ;;
    --open)
        OPEN=1
        shift
        ;;
    --clone-if-missing)
        CLONE_MISSING=1
        shift
        ;;
    --user)
        BASE_USER="$2"
        shift 2
        ;;
    --user=*)
        BASE_USER="${1#*=}"
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown argument: $1" >&2
        usage
        exit 2
        ;;
    esac
done

# Iterate through discovered repo directories if they exist under current root
for r in "${REPOS[@]}"; do
    github_repo="$(get_github_name "$r")"
    if [[ "${r}" == "${REPO_NAME}" ]]; then
        repo_path="${REPO_ROOT}"
    else
        repo_path="${REPO_ROOT}/${r}"
    fi
    if [[ ! -d "${repo_path}" ]]; then
        if [[ ${CLONE_MISSING} -eq 1 ]]; then
            if [[ ${DRY_RUN} -eq 1 ]]; then
                echo "[${r}] DRY RUN: would clone https://github.com/${BASE_USER}/${github_repo}.git to ${repo_path}"
                # In dry-run, assume clone succeeds for further checks
            else
                echo "[${r}] Cloning https://github.com/${BASE_USER}/${github_repo}.git to ${repo_path}"
                git clone "https://github.com/${BASE_USER}/${github_repo}.git" "${repo_path}"
            fi
        else
            echo "Skipping ${r}: directory not found at ${repo_path}"
            continue
        fi
    fi

    if [[ ! -d "${repo_path}/.git" ]]; then
        if [[ ${CLONE_MISSING} -eq 1 ]]; then
            if [[ ${DRY_RUN} -eq 1 ]]; then
                echo "[${r}] DRY RUN: would init git repo and add remote https://github.com/${BASE_USER}/${github_repo}.git"
            else
                echo "[${r}] Initializing git repo and adding remote https://github.com/${BASE_USER}/${github_repo}.git"
                pushd "${repo_path}" >/dev/null
                git init
                git remote add view "https://github.com/${BASE_USER}/${github_repo}.git"
                popd >/dev/null
            fi
        else
            echo "Skipping ${r}: not a git repository (no .git in ${repo_path})"
            continue
        fi
    fi

    pushd "${repo_path}" >/dev/null
    remote_name=view
    remote_url="https://github.com/${BASE_USER}/${github_repo}.git"

    # Does remote already exist?
    if git remote get-url ${remote_name} >/dev/null 2>&1; then
        existing_url=$(git remote get-url ${remote_name})
        echo "[${r}] remote '${remote_name}' already exists -> ${existing_url}"
    else
        if [[ ${DRY_RUN} -eq 1 ]]; then
            echo "[${r}] DRY RUN: would run: git remote add ${remote_name} ${remote_url}"
        else
            echo "[${r}] Adding remote '${remote_name}' -> ${remote_url}"
            git remote add "${remote_name}" "${remote_url}"
        fi
    fi

    # optionally open in a browser
    if [[ ${OPEN} -eq 1 ]]; then
        if [[ ${DRY_RUN} -eq 1 ]]; then
            echo "[${r}] DRY RUN: would open ${remote_url} in browser"
        else
            echo "[${r}] Opening ${remote_url} in browser"
            # macOS open, fallback to xdg-open on other systems
            if command -v open >/dev/null 2>&1; then
                open "${remote_url}"
            elif command -v xdg-open >/dev/null 2>&1; then
                xdg-open "${remote_url}"
            else
                echo "Unable to open browser. Please open ${remote_url} manually."
            fi
        fi
    fi

    popd >/dev/null
done

echo "Script completed. To remove a 'view' remote: git remote remove view"
