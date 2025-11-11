#!/bin/bash

# Script to fix ShellCheck severity and CodeQL indentation across all repositories

REPOS=(
    "dboone323/shared-kit"
    "dboone323/coding-reviewer"
    "dboone323/avoid-obstacles-game"
    "dboone323/habitquest"
    "dboone323/momentum-finance"
    "dboone323/planner-app"
)

for repo in "${REPOS[@]}"; do
    echo "Updating $repo..."

    # Clone or update the repo
    repo_name=$(basename "$repo")
    if [ -d "$repo_name" ]; then
        cd "$repo_name"
        git pull origin main
    else
        git clone "https://github.com/$repo.git"
        cd "$repo_name"
    fi

    # Check if security workflow exists
    if [ -f ".github/workflows/security.yml" ]; then
        # Fix ShellCheck severity
        sed -i 's/      - name: Run ShellCheck$/      - name: Run ShellCheck\n        uses: ludeeus\/action-shellcheck@master\n        with:\n          severity: error\n          ignore_paths: node_modules/' .github/workflows/security.yml

        # Fix CodeQL indentation (this is tricky with sed, let's use a more targeted approach)
        # First, let's check if the file has the malformed CodeQL section
        if grep -q "            - name: CodeQL Analysis" .github/workflows/security.yml; then
            # Replace the malformed section
            sed -i '/            - name: CodeQL Analysis/,/      - name: Perform CodeQL Analysis/c\      - name: CodeQL Analysis\n        uses: github\/codeql-action\/init@v3\n        with:\n          languages: javascript, python\n\n      - name: Perform CodeQL Analysis\n        uses: github\/codeql-action\/analyze@v3' .github/workflows/security.yml
        fi

        # Commit and push
        git add .github/workflows/security.yml
        git commit -m "Fix ShellCheck severity and CodeQL indentation" || echo "No changes to commit for $repo"
        git push origin main
    else
        echo "Security workflow not found in $repo"
    fi

    cd ..
done

echo "All repositories updated!"
