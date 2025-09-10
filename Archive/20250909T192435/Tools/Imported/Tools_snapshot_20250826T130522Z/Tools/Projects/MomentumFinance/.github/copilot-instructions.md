<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Momentum Finance - SwiftUI Personal Finance App

This is a comprehensive personal finance application built with SwiftUI and SwiftData for iOS and macOS platforms.

## Architecture Guidelines

- **MVVM Pattern**: All views should have corresponding ViewModels
- **SwiftData**: Use for all data persistence with proper relationships
- **Modular Design**: Each feature module has its own folder with Views/ViewModels
- **Multi-Platform**: Shared core logic, separate UI optimizations for iOS/macOS
- **Clean Code**: Follow SwiftLint rules and maintain clear separation of concerns

## Core Features

1. **Dashboard**: Overview of accounts, subscriptions, and budget progress
2. **Transactions**: Income/expense tracking with categorization
3. **Budgets**: Monthly spending limits and progress tracking
4. **Subscriptions**: Recurring payment management
5. **Goals & Reports**: Savings goals and financial insights

## Key Models

- FinancialAccount, Transaction, Subscription, Budget, Category, SavingsGoal
- All models use SwiftData with proper relationships
- Automatic transaction generation from subscriptions

## Development Standards

- Use SwiftUI best practices
- Implement proper error handling
- Follow iOS/macOS design guidelines
- Maintain data consistency across platforms
