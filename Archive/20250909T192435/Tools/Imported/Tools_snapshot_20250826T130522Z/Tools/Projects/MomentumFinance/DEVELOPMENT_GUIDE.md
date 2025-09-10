# MomentumFinance Development Guide

## Quick Start

### Running the App
```bash
# Using the development helper script
./dev.sh run

# Or directly with Swift Package Manager
swift run MomentumFinance
```

### Development Commands
```bash
# Check project status
./dev.sh status

# Build project
./dev.sh build

# Run SwiftLint checks
./dev.sh lint

# Auto-fix SwiftLint issues
./dev.sh lint-fix

# Open in Xcode
./dev.sh xcode

# Check dependencies
./dev.sh deps

# Clean build artifacts
./dev.sh clean
```

## Development Workflow

### 1. Making Code Changes
1. Edit Swift files in your preferred editor (VS Code, Xcode, etc.)
2. Run `./dev.sh lint` to check code style
3. Run `./dev.sh build` to verify compilation
4. Run `./dev.sh run` to test the app

### 2. Code Quality Standards
- **SwiftLint**: All code must pass SwiftLint checks (0 violations)
- **Architecture**: Follow MVVM pattern with SwiftData
- **Platform Support**: Test on both iOS and macOS
- **Documentation**: Add comments for complex logic

### 3. File Structure Guidelines
```
Shared/
├── Features/           # Feature modules (Dashboard, Transactions, etc.)
│   ├── Dashboard/      # Each feature has its own folder
│   ├── Transactions/   
│   └── ...
├── Models/             # SwiftData models
├── Navigation/         # Navigation coordination
└── Utilities/          # Shared utilities
```

## VS Code Integration

### Available Tasks
- **Build with Swift Package Manager**: `Cmd+Shift+P` → "Tasks: Run Task" → "Build"
- **Run App**: Starts the MomentumFinance app
- **SwiftLint Check**: Code quality verification
- **SwiftLint Auto-Fix**: Automatic code formatting

### Recommended Extensions
- Swift Language Support
- GitLens (if using Git)
- Error Lens
- Bracket Pair Colorizer

## Architecture Overview

### Core Components
1. **SwiftData Models**: Data persistence layer
2. **MVVM ViewModels**: Business logic separation
3. **NavigationCoordinator**: Cross-module navigation
4. **Feature Modules**: Self-contained functionality

### Key Models
- `FinancialAccount`: Bank accounts and balances
- `FinancialTransaction`: Income and expense tracking
- `Subscription`: Recurring payments
- `Budget`: Spending limits and categories
- `SavingsGoal`: Financial targets

### Navigation Flow
```
ContentView (TabView)
├── Dashboard → Cross-module navigation
├── Transactions → Account details
├── Budgets → Category management
├── Subscriptions → Payment tracking
└── Goals → Progress monitoring
```

## Platform Considerations

### iOS Specific
- Navigation bar styling
- Tab bar icons with filled/outlined states
- Touch-optimized interactions
- System colors and fonts

### macOS Specific
- Window sizing constraints
- Menu bar integration
- Keyboard shortcuts
- Mouse/trackpad interactions

## Troubleshooting

### Common Issues
1. **Build Errors**: Run `./dev.sh clean` then `./dev.sh build`
2. **SwiftLint Violations**: Run `./dev.sh lint-fix` for auto-fixes
3. **Navigation Issues**: Check NavigationCoordinator implementation
4. **Data Issues**: Verify SwiftData model relationships

### Performance Tips
- Use LazyVStack for large lists
- Implement proper @Query filtering
- Optimize image loading and caching
- Use animations judiciously

## Testing Strategy

### Manual Testing
- Test on both iOS simulator and macOS
- Verify navigation flows
- Check data persistence
- Validate responsive design

### Future Automated Testing
- Unit tests for ViewModels
- Integration tests for data layer
- UI tests for critical user flows

## Deployment

### iOS App Store
1. Update version in Package.swift
2. Test on physical devices
3. Generate app icons and screenshots
4. Submit via Xcode

### macOS App Store
1. Configure entitlements
2. Test sandboxing compatibility
3. Package for distribution
4. Submit via Xcode

## Contributing Guidelines

### Code Style
- Follow SwiftLint rules (configured in .swiftlint.yml)
- Use descriptive variable names
- Add documentation for public APIs
- Keep functions focused and small

### Git Workflow (when using Git)
1. Create feature branches
2. Make focused commits
3. Write descriptive commit messages
4. Test before merging

### Review Process
- Ensure all builds pass
- Verify SwiftLint compliance
- Test on multiple platforms
- Review navigation changes carefully

## Resources

### Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [SwiftData Guide](https://developer.apple.com/documentation/swiftdata/)
- [Swift Package Manager](https://swift.org/package-manager/)

### Design Guidelines
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)

---

**Happy Coding! 🚀**
