#!/bin/bash
# filepath: /Users/danielstevens/Desktop/MomentumFinaceApp/verify-project.sh
# Momentum Finance - Project Verification Script
# This script verifies that all necessary files and structure are in place

set -e  # Exit on any error

echo "🚀 Momentum Finance - Project Verification"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    if [ "$2" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ $1${NC}"
    elif [ "$2" = "WARNING" ]; then
        echo -e "${YELLOW}⚠️  $1${NC}"
    elif [ "$2" = "ERROR" ]; then
        echo -e "${RED}❌ $1${NC}"
    else
        echo -e "${BLUE}📋 $1${NC}"
    fi
}

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        print_status "Found: $1" "SUCCESS"
        return 0
    else
        print_status "Missing: $1" "ERROR"
        return 1
    fi
}

# Function to check if directory exists
check_directory() {
    if [ -d "$1" ]; then
        print_status "Directory: $1" "SUCCESS"
        return 0
    else
        print_status "Missing directory: $1" "ERROR"
        return 1
    fi
}

# Initialize counters
total_checks=0
passed_checks=0

# Check project structure
echo ""
print_status "Checking project structure..." "INFO"

directories=(
    "Shared"
    "Shared/Models"
    "Shared/Features"
    "Shared/Features/Dashboard"
    "Shared/Features/Transactions"
    "Shared/Features/Budgets"
    "Shared/Features/Subscriptions"
    "Shared/Features/GoalsAndReports"
    "Shared/Utilities"
    "iOS"
    "macOS"
)

for dir in "${directories[@]}"; do
    total_checks=$((total_checks + 1))
    if check_directory "$dir"; then
        passed_checks=$((passed_checks + 1))
    fi
done

# Check core app files
echo ""
print_status "Checking core application files..." "INFO"

core_files=(
    "Shared/MomentumFinanceApp.swift"
    "Shared/ContentView.swift"
)

for file in "${core_files[@]}"; do
    total_checks=$((total_checks + 1))
    if check_file "$file"; then
        passed_checks=$((passed_checks + 1))
    fi
done

# Check model files
echo ""
print_status "Checking SwiftData model files..." "INFO"

model_files=(
    "Shared/Models/FinancialAccount.swift"
    "Shared/Models/Transaction.swift"
    "Shared/Models/Category.swift"
    "Shared/Models/Subscription.swift"
    "Shared/Models/Budget.swift"
    "Shared/Models/SavingsGoal.swift"
)

for file in "${model_files[@]}"; do
    total_checks=$((total_checks + 1))
    if check_file "$file"; then
        passed_checks=$((passed_checks + 1))
    fi
done

# Check feature modules
echo ""
print_status "Checking feature module files..." "INFO"

feature_files=(
    "Shared/Features/Dashboard/DashboardView.swift"
    "Shared/Features/Dashboard/DashboardViewModel.swift"
    "Shared/Features/Transactions/TransactionsView.swift"
    "Shared/Features/Transactions/TransactionsViewModel.swift"
    "Shared/Features/Budgets/BudgetsView.swift"
    "Shared/Features/Budgets/BudgetsViewModel.swift"
    "Shared/Features/Subscriptions/SubscriptionsView.swift"
    "Shared/Features/Subscriptions/SubscriptionsViewModel.swift"
    "Shared/Features/GoalsAndReports/GoalsAndReportsView.swift"
    "Shared/Features/GoalsAndReports/GoalsAndReportsViewModel.swift"
)

for file in "${feature_files[@]}"; do
    total_checks=$((total_checks + 1))
    if check_file "$file"; then
        passed_checks=$((passed_checks + 1))
    fi
done

# Check utility files
echo ""
print_status "Checking utility files..." "INFO"

utility_files=(
    "Shared/Utilities/Logger.swift"
    "Shared/Utilities/ErrorHandler.swift"
)

for file in "${utility_files[@]}"; do
    total_checks=$((total_checks + 1))
    if check_file "$file"; then
        passed_checks=$((passed_checks + 1))
    fi
done

# Check configuration files
echo ""
print_status "Checking configuration files..." "INFO"

config_files=(
    ".gitignore"
    ".swiftlint.yml"
    ".github/copilot-instructions.md"
)

for file in "${config_files[@]}"; do
    total_checks=$((total_checks + 1))
    if check_file "$file"; then
        passed_checks=$((passed_checks + 1))
    fi
done

# Check for SwiftData imports in model files
echo ""
print_status "Checking SwiftData imports..." "INFO"

for file in "${model_files[@]}"; do
    if [ -f "$file" ]; then
        total_checks=$((total_checks + 1))
        if grep -q "import SwiftData" "$file"; then
            print_status "SwiftData import found in $(basename "$file")" "SUCCESS"
            passed_checks=$((passed_checks + 1))
        else
            print_status "Missing SwiftData import in $(basename "$file")" "ERROR"
        fi
    fi
done

# Check for Observable conformance in ViewModels
echo ""
print_status "Checking ViewModel patterns..." "INFO"

viewmodel_files=(
    "Shared/Features/Dashboard/DashboardViewModel.swift"
    "Shared/Features/Transactions/TransactionsViewModel.swift"
    "Shared/Features/Budgets/BudgetsViewModel.swift"
    "Shared/Features/Subscriptions/SubscriptionsViewModel.swift"
    "Shared/Features/GoalsAndReports/GoalsAndReportsViewModel.swift"
)

for file in "${viewmodel_files[@]}"; do
    if [ -f "$file" ]; then
        total_checks=$((total_checks + 1))
        if grep -q "ObservableObject\|@Observable" "$file"; then
            print_status "Observable pattern found in $(basename "$file")" "SUCCESS"
            passed_checks=$((passed_checks + 1))
        else
            print_status "Missing Observable pattern in $(basename "$file")" "ERROR"
        fi
    fi
done

# Check file sizes (basic sanity check)
echo ""
print_status "Checking file sizes..." "INFO"

large_files=0
for file in "${model_files[@]}" "${feature_files[@]}"; do
    if [ -f "$file" ]; then
        size=$(wc -l < "$file" 2>/dev/null || echo "0")
        if [ "$size" -gt 10 ]; then
            large_files=$((large_files + 1))
        fi
    fi
done

total_checks=$((total_checks + 1))
if [ "$large_files" -gt 8 ]; then
    print_status "File sizes look reasonable ($large_files substantial files)" "SUCCESS"
    passed_checks=$((passed_checks + 1))
else
    print_status "Some files may be too small ($large_files substantial files)" "WARNING"
fi

# Check for TODO/FIXME comments
echo ""
print_status "Checking for TODO/FIXME comments..." "INFO"

todo_count=0
for file in "${model_files[@]}" "${feature_files[@]}" "${utility_files[@]}"; do
    if [ -f "$file" ]; then
        todos=$(grep -c "TODO\|FIXME" "$file" 2>/dev/null || echo "0")
        todo_count=$((todo_count + todos))
    fi
done

total_checks=$((total_checks + 1))
if [ "$todo_count" -eq 0 ]; then
    print_status "No TODO/FIXME comments found" "SUCCESS"
    passed_checks=$((passed_checks + 1))
else
    print_status "Found $todo_count TODO/FIXME comments" "WARNING"
fi

# Summary
echo ""
echo "=========================================="
print_status "VERIFICATION SUMMARY" "INFO"
echo "=========================================="

percentage=$((passed_checks * 100 / total_checks))

echo -e "Total checks: ${BLUE}$total_checks${NC}"
echo -e "Passed: ${GREEN}$passed_checks${NC}"
echo -e "Failed: ${RED}$((total_checks - passed_checks))${NC}"
echo -e "Success rate: ${BLUE}$percentage%${NC}"

echo ""

if [ "$percentage" -ge 90 ]; then
    print_status "✨ Project structure looks excellent! Ready for development." "SUCCESS"
    exit 0
elif [ "$percentage" -ge 75 ]; then
    print_status "👍 Project structure looks good with minor issues." "WARNING"
    exit 0
else
    print_status "❗ Project structure has significant issues that should be addressed." "ERROR"
    exit 1
fi
