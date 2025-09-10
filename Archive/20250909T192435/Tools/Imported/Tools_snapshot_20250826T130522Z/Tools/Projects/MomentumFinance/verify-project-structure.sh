#!/bin/bash
# Momentum Finance App Project Structure Verification
# This script verifies that your project follows the MVVM architecture guidelines

echo "🔍 Verifying Momentum Finance App Project Structure"
echo "=================================================="

# Check for duplicate model files
echo -e "\n📊 Checking for duplicate model files..."
DUPLICATE_COUNT=0

MODEL_FILES=("Budget.swift" "Category.swift" "ComplexDataGenerators.swift" "ExpenseCategory.swift" 
             "FinancialAccount.swift" "FinancialTransaction.swift" "SampleData.swift" 
             "SampleDataGenerators.swift" "SampleDataProviders.swift" "SavingsGoal.swift" 
             "Subscription.swift" "Transaction.swift")
             
for file in "${MODEL_FILES[@]}"; do
    ROOT_COUNT=$(find /Users/danielstevens/Desktop/MomentumFinaceApp -name "$file" | wc -l | tr -d ' ')
    if [ "$ROOT_COUNT" -gt 1 ]; then
        echo "⚠️  DUPLICATE: $file exists in multiple locations:"
        find /Users/danielstevens/Desktop/MomentumFinaceApp -name "$file" | sed 's/^/      /'
        DUPLICATE_COUNT=$((DUPLICATE_COUNT + 1))
    else
        echo "✅ $file: OK"
    fi
done

if [ "$DUPLICATE_COUNT" -gt 0 ]; then
    echo -e "\n⚠️  Found $DUPLICATE_COUNT duplicate model files! This can cause confusion and build errors."
    echo "    Recommendation: Keep models only in /Shared/Models/ directory"
else
    echo -e "\n✅ No duplicate model files found!"
fi

# Check for proper MVVM structure in feature modules
echo -e "\n📱 Checking feature modules for MVVM structure..."
FEATURES=("Dashboard" "Transactions" "Budgets" "Subscriptions" "GoalsAndReports")
FEATURE_ISSUES=0

for feature in "${FEATURES[@]}"; do
    echo "Checking $feature module..."
    
    # Check for View files
    VIEW_COUNT=$(find /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Features/$feature -name "*View*.swift" | wc -l | tr -d ' ')
    
    # Check for ViewModel files
    VIEWMODEL_COUNT=$(find /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Features/$feature -name "*ViewModel*.swift" | wc -l | tr -d ' ')
    
    if [ "$VIEW_COUNT" -eq 0 ]; then
        echo "⚠️  $feature: Missing View files"
        FEATURE_ISSUES=$((FEATURE_ISSUES + 1))
    fi
    
    if [ "$VIEWMODEL_COUNT" -eq 0 ]; then
        echo "⚠️  $feature: Missing ViewModel files"
        FEATURE_ISSUES=$((FEATURE_ISSUES + 1))
    fi
    
    if [ "$VIEW_COUNT" -gt 0 ] && [ "$VIEWMODEL_COUNT" -gt 0 ]; then
        echo "✅ $feature: Complete MVVM structure (Views: $VIEW_COUNT, ViewModels: $VIEWMODEL_COUNT)"
    fi
done

if [ "$FEATURE_ISSUES" -gt 0 ]; then
    echo -e "\n⚠️  Found $FEATURE_ISSUES issues with feature modules!"
    echo "    Recommendation: Ensure each feature has both View and ViewModel files"
else
    echo -e "\n✅ All feature modules have proper MVVM structure!"
fi

# Check app entry point
echo -e "\n🚀 Checking app entry point..."

APP_FILES=$(find /Users/danielstevens/Desktop/MomentumFinaceApp -name "MomentumFinanceApp.swift" | wc -l | tr -d ' ')

if [ "$APP_FILES" -gt 1 ]; then
    echo "⚠️  Multiple app entry points found:"
    find /Users/danielstevens/Desktop/MomentumFinaceApp -name "MomentumFinanceApp.swift" | sed 's/^/      /'
    echo "    Recommendation: Keep only /Shared/MomentumFinanceApp.swift"
else
    if [ -f "/Users/danielstevens/Desktop/MomentumFinaceApp/Shared/MomentumFinanceApp.swift" ]; then
        echo "✅ App entry point correctly located at /Shared/MomentumFinanceApp.swift"
    else
        echo "⚠️  App entry point not in expected location (/Shared/MomentumFinanceApp.swift)"
    fi
fi

# Check for platform-specific optimizations
echo -e "\n🖥️ Checking platform-specific code..."

if [ -d "/Users/danielstevens/Desktop/MomentumFinaceApp/iOS" ] && [ -d "/Users/danielstevens/Desktop/MomentumFinaceApp/macOS" ]; then
    echo "✅ Platform-specific directories exist (iOS and macOS)"
    
    iOS_FILES=$(find /Users/danielstevens/Desktop/MomentumFinaceApp/iOS -name "*.swift" | wc -l | tr -d ' ')
    MACOS_FILES=$(find /Users/danielstevens/Desktop/MomentumFinaceApp/macOS -name "*.swift" | wc -l | tr -d ' ')
    
    echo "   - iOS directory: $iOS_FILES Swift files"
    echo "   - macOS directory: $MACOS_FILES Swift files"
else
    echo "⚠️  Missing platform-specific directories"
fi

# Final summary
echo -e "\n📋 Project Structure Verification Summary"
echo "========================================"

TOTAL_ISSUES=$((DUPLICATE_COUNT + FEATURE_ISSUES + (APP_FILES - 1)))

if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo "✅ Your project structure looks excellent! No issues found."
else
    echo "⚠️  Found $TOTAL_ISSUES issues that should be addressed."
fi

echo -e "\nRecommendations:"
echo "1. Run the 'add_missing_files_to_xcode.sh' script to add missing files to your Xcode project"
echo "2. Ensure all models are ONLY in the Shared/Models directory"
echo "3. Use a single app entry point in Shared/MomentumFinanceApp.swift"
echo "4. Make sure all features follow MVVM with proper ViewModels"
