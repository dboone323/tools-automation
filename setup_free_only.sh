#!/bin/bash
#
# Free-Only Setup Script
# Migrates workspace to 100% free tools and services
#
# What this does:
# 1. Updates Ollama to latest version
# 2. Pulls latest free models
# 3. Installs Git hooks for local CI/CD
# 4. Removes paid API references
# 5. Updates VS Code extensions (optional)
# 6. Sets up local artifact storage
# 7. Disables GitHub Actions workflows
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║    🆓 Free-Only Workspace Setup                              ║"
    echo "║    Migrating to 100% Free Tools & Services                   ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

info() { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warning() { echo -e "${YELLOW}⚠️${NC}  $*"; }
error() { echo -e "${RED}❌${NC} $*"; }
step() { echo -e "${PURPLE}▶${NC}  $*"; }

# Find root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

banner

# Step 1: Update Ollama
step "Step 1: Updating Ollama to latest version..."

if ! command -v ollama >/dev/null 2>&1; then
    warning "Ollama not installed"
    info "Install with: brew install ollama"
    info "Or visit: https://ollama.com/download"
else
    info "Current Ollama version:"
    ollama --version

    if command -v brew >/dev/null 2>&1; then
        info "Updating via Homebrew..."
        brew upgrade ollama || {
            info "Ollama already at latest version or upgrade failed"
        }
    else
        info "Homebrew not found - manual update may be needed"
        info "Visit: https://ollama.com/download"
    fi

    success "Ollama update complete"
fi

# Step 2: Pull latest free models
step "Step 2: Pulling latest free Ollama models..."

if command -v ollama >/dev/null 2>&1; then
    # Start Ollama if not running
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        info "Starting Ollama server..."
        ollama serve >/dev/null 2>&1 &
        sleep 3
    fi

    # Pull recommended models
    models=(
        "qwen2.5-coder:1.5b" # Fast coding (1GB)
        "codellama:7b"       # Code review (4GB)
        "mistral:7b"         # General purpose (4GB)
    )

    for model in "${models[@]}"; do
        if ollama list | grep -q "$(echo "$model" | cut -d: -f1)"; then
            info "Model ${model} already available"
        else
            info "Pulling ${model} (this may take a few minutes)..."
            ollama pull "$model"
        fi
    done

    success "Ollama models ready"
else
    warning "Ollama not installed - skipping model pull"
fi

# Step 3: Install Git hooks
step "Step 3: Installing Git hooks for local CI/CD..."

cd "$ROOT_DIR"

if [ -d ".git" ]; then
    # Copy hooks
    cp "$SCRIPT_DIR/git_hooks/pre-commit" ".git/hooks/pre-commit"
    cp "$SCRIPT_DIR/git_hooks/pre-push" ".git/hooks/pre-push"

    # Make executable
    chmod +x ".git/hooks/pre-commit"
    chmod +x ".git/hooks/pre-push"

    success "Git hooks installed"
    info "  - pre-commit: Lint, format, syntax check (< 10s)"
    info "  - pre-push: Tests, AI review, quality gates (< 2min)"
    info "  - Bypass with: git commit/push --no-verify"
else
    warning "Not a git repository - skipping git hooks"
fi

# Step 4: Remove paid API references
step "Step 4: Removing paid API key references..."

# Remove .env files with paid API keys (keep as example only)
if [ -f "$ROOT_DIR/.secure/.env.secure" ]; then
    if grep -q "OPENAI_API_KEY\|ANTHROPIC_API_KEY" "$ROOT_DIR/.secure/.env.secure"; then
        warning "Found paid API keys in .secure/.env.secure"
        info "Backing up to .env.secure.backup..."
        cp "$ROOT_DIR/.secure/.env.secure" "$ROOT_DIR/.secure/.env.secure.backup"

        # Comment out paid keys
        sed -i.bak 's/^OPENAI_API_KEY=/#OPENAI_API_KEY=/g' "$ROOT_DIR/.secure/.env.secure" 2>/dev/null || true
        sed -i.bak 's/^ANTHROPIC_API_KEY=/#ANTHROPIC_API_KEY=/g' "$ROOT_DIR/.secure/.env.secure" 2>/dev/null || true

        success "Paid API keys disabled (backed up)"
    fi
fi

# Update .gitignore to ignore API keys
if [ -f "$ROOT_DIR/.gitignore" ]; then
    if ! grep -q ".env.secure" "$ROOT_DIR/.gitignore"; then
        echo -e "\n# API Keys (keep local only)" >>"$ROOT_DIR/.gitignore"
        echo ".secure/.env.secure" >>"$ROOT_DIR/.gitignore"
        echo ".env" >>"$ROOT_DIR/.gitignore"
        success "Updated .gitignore"
    fi
fi

# Step 5: Set up local artifact storage
step "Step 5: Setting up local artifact storage..."

ARTIFACTS_DIR="${HOME}/.quantum-workspace/artifacts"

mkdir -p "$ARTIFACTS_DIR"/{logs,reports,reviews,baselines,coverage,test-results,performance}

success "Local artifact storage created at: $ARTIFACTS_DIR"
info "  - Logs: $ARTIFACTS_DIR/logs/"
info "  - Reports: $ARTIFACTS_DIR/reports/"
info "  - Reviews: $ARTIFACTS_DIR/reviews/"
info "  - Coverage: $ARTIFACTS_DIR/coverage/"

# Step 6: Update tool versions
step "Step 6: Checking dev tool versions..."

tools=(
    "swiftlint:SwiftLint"
    "swiftformat:SwiftFormat"
    "python3:Python"
    "node:Node.js"
    "jq:jq"
)

for tool_spec in "${tools[@]}"; do
    tool=$(echo "$tool_spec" | cut -d: -f1)
    name=$(echo "$tool_spec" | cut -d: -f2)

    if command -v "$tool" >/dev/null 2>&1; then
        version=$("$tool" --version 2>&1 | head -1 || echo "unknown")
        success "$name: $version"
    else
        warning "$name not installed (optional)"
        if [ "$tool" = "swiftlint" ] || [ "$tool" = "swiftformat" ]; then
            info "  Install with: brew install $tool"
        fi
    fi
done

# Step 7: Disable GitHub Actions workflows (make them opt-in)
step "Step 7: Marking GitHub Actions workflows as opt-in..."

cd "$ROOT_DIR/.github/workflows"

# Don't automatically disable - just inform
active_workflows=$(ls *.yml 2>/dev/null | grep -v disabled | wc -l)
info "Found $active_workflows active GitHub Actions workflows"
info "These will now run in parallel with local CI/CD"
info "To disable a workflow: mv workflow.yml workflow.disabled.yml"

success "GitHub Actions status: Opt-in (can be disabled manually)"

# Step 8: Make local orchestrator executable
step "Step 8: Setting up local CI/CD orchestrator..."

chmod +x "$SCRIPT_DIR/local_ci_orchestrator.sh"

success "Local CI/CD orchestrator ready"
info "  Run with: Tools/Automation/local_ci_orchestrator.sh [mode]"
info "  Modes: full, quick, projects, review"

# Step 9: Create daily monitoring cron job (optional)
step "Step 9: Daily monitoring setup (optional)..."

info "To enable daily monitoring, add to crontab:"
echo -e "${CYAN}  0 6 * * * cd ${ROOT_DIR} && Tools/Automation/local_ci_orchestrator.sh full > ~/.quantum-workspace/artifacts/logs/daily_\$(date +\\%Y\\%m\\%d).log 2>&1${NC}"
info ""
info "Add with: crontab -e"

# Final summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                  ✅ Setup Complete!                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 Summary:${NC}"
echo "  ✅ Ollama updated with latest models"
echo "  ✅ Git hooks installed (pre-commit, pre-push)"
echo "  ✅ Paid API references disabled"
echo "  ✅ Local artifact storage configured"
echo "  ✅ Local CI/CD orchestrator ready"
echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
echo "  1. Test local CI/CD: ./Tools/Automation/local_ci_orchestrator.sh quick"
echo "  2. Make a commit to test git hooks"
echo "  3. Review migration plan: FREE_ONLY_MIGRATION_PLAN.md"
echo "  4. Optional: Set up daily cron job"
echo ""
echo -e "${CYAN}💰 Cost Savings:${NC}"
echo "  Before: \$0-20/month (GitHub Actions)"
echo "  After:  \$0/month (100% local + Ollama)"
echo ""
echo -e "${GREEN}Everything is now FREE! 🎉${NC}"
echo ""
