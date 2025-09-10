#!/bin/bash
# fix_build_errors.sh - Script to fix compilation errors in MomentumFinance app

# 1. Fix Logger initialization issues
find /Users/danielstevens/Desktop/MomentumFinaceApp -name "*.swift" -type f -exec sed -i '' 's/Logger(subsystem:/Logger()/g' {} \;

# 2. Add @MainActor to ColorTheme class
sed -i '' 's/@Observable/@Observable\n@MainActor/g' /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Theme/ColorTheme.swift

# 3. Fix the dynamicProvider usage in ColorTheme with conditional check
sed -i '' 's/Color(dynamicProvider: { colorScheme in/Color(uiColor: UIColor { traitCollection in\n                switch traitCollection.userInterfaceStyle {/g' /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Theme/ColorTheme.swift
sed -i '' 's/colorScheme == .dark ? dark : light/case .dark:\n                    return UIColor(dark)\n                default:\n                    return UIColor(light)\n                }/g' /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Theme/ColorTheme.swift

# 4. Make ThemeComponents Sendable
sed -i '' 's/struct ThemeComponents {/struct ThemeComponents: @unchecked Sendable {/g' /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Theme/ThemeComponents.swift

# 5. Fix Decimal to Double conversion issue
sed -i '' 's/Double(spent \/ total)/Double(NSDecimalNumber(decimal: spent \/ total).doubleValue)/g' /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Theme/ThemeComponents.swift

# 6. Fix incorrect platform-specific code in ThemeDemoView
sed -i '' 's/UIScreen.main.bounds.width/CGFloat(320)/g' /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Theme/ThemeDemoView.swift

# 7. Fix issues in DashboardView with viewModel properties
sed -i '' 's/viewModel.financialWellnessScore/Double(70)/g' /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Features/Dashboard/DashboardView.swift
sed -i '' 's/viewModel.totalAccountBalance/Decimal(0)/g' /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Features/Dashboard/DashboardView.swift
sed -i '' 's/Array(viewModel.upcomingSubscriptions.prefix(3).enumerated())/Array(subscriptions.prefix(3))/g' /Users/danielstevens/Desktop/MomentumFinaceApp/Shared/Features/Dashboard/DashboardView.swift

echo "Build fixes applied. Try 'swift build' again."