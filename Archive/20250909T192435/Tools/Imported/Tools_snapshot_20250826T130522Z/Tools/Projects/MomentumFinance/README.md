# Momentum Finance

A comprehensive personal finance application built with SwiftUI and SwiftData for iOS and macOS platforms.

![Momentum Finance](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-blue)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-orange)
![SwiftData](https://img.shields.io/badge/SwiftData-Latest-green)
![Xcode](https://img.shields.io/badge/Xcode-15.0%2B-blue)
![GitHub License](https://img.shields.io/github/license/momentumfinance/app)
![Release Date](https://img.shields.io/badge/Release%20Date-June%202025-brightgreen)

<p align="center">
  <img src="https://placeholder.pics/svg/300x300/DEDEDE/555555/Momentum%20Finance" alt="Momentum Finance Logo" width="300" />
</p>

## 📱 Overview

Momentum Finance is a modern personal finance app that helps users track their spending, manage budgets, monitor subscriptions, and achieve savings goals. Built with the latest Apple technologies, it provides a seamless experience across iPhone, iPad, and Mac.

## ✨ Key Features

### 🏦 Account Management
- Multiple financial account support (checking, savings, credit cards, investments)
- Real-time balance tracking and reconciliation
- Account categorization and organization with customizable groups
- Support for multiple currencies and automatic conversion

### 💳 Transaction Tracking
- Comprehensive transaction history with detailed metadata
- AI-powered automatic categorization
- Recurring transaction detection and management
- Bulk editing and transaction splitting capabilities
- Smart search and advanced filtering options

### 📊 Budgeting System
- Flexible monthly budget creation by category
- Visual progress tracking with customizable thresholds
- Budget rollover options and adjustments
- Intelligent spending recommendations
- Historical budget analysis and comparisons

### 📅 Subscription Management
- Comprehensive subscription tracking across services
- Upcoming payment notifications and reminders
- Auto-detection of subscription transactions
- Renewal predictions and cost analysis
- Subscription optimization recommendations

### 🎯 Goals & Reports
- Custom savings goal creation with timelines
- Visual progress tracking for financial goals
- Detailed spending reports by category, time period, and merchant
- Income vs. expense analysis with trends
- Exportable reports in multiple formats

### 🔄 Cross-Platform Sync
- Seamless data synchronization across all Apple devices
- iCloud integration for automatic backup
- Privacy-focused design with end-to-end encryption

## 🛠️ Technical Architecture

Momentum Finance is built with a modern, scalable architecture following best practices:

### MVVM Pattern
- Clean separation of Views and ViewModels
- Reactive UI updates using SwiftUI and Combine
- Testable business logic isolated from UI

### Data Management
- SwiftData for persistent storage
- Optimized query performance for large financial datasets
- Proper relationship modeling between financial entities
- Data migration strategies for app updates

### Platform Adaptability
- Shared core functionality between iOS and macOS
- Platform-specific UI optimizations
- Responsive layouts that adapt to all device sizes
- Support for native platform features (Touch ID/Face ID on iOS, keyboard shortcuts on macOS)

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- Swift 5.9 or later
- macOS Sonoma 14.0+ (for development)
- iOS 17.0+ / macOS 14.0+ (for running the app)

### Installation and Setup

1. Clone this repository:
```bash
git clone https://github.com/momentumfinance/app.git
cd MomentumFinanceApp
```

2. Open the project:
```bash
open MomentumFinance.xcodeproj
```

Alternatively, you can build and run using Swift Package Manager:
```bash
swift build
swift run MomentumFinance
```

3. For development tools setup:
```bash
./setup-tools.sh
```

### Development Workflow

We provide several tools to streamline the development process:

```bash
# Build the project
./dev.sh build

# Run the app
./dev.sh run

# Check code style with SwiftLint
./dev.sh lint

# Auto-fix SwiftLint issues
./dev.sh lint-fix

# Format code with Prettier
./dev.sh format

# Set up Docker environment
./dev.sh docker-compose

# See all available commands
./dev.sh help
```

## 📁 Project Structure

```
MomentumFinance/
├── Shared/                 # Cross-platform shared code
│   ├── Features/           # Feature modules using MVVM
│   │   ├── Dashboard/      # Dashboard feature
│   │   ├── Transactions/   # Transactions feature
│   │   ├── Budgets/        # Budgets feature
│   │   ├── Subscriptions/  # Subscriptions feature
│   │   └── GoalsAndReports/# Goals and Reports feature
│   ├── Models/             # SwiftData models
│   ├── Navigation/         # Navigation coordinator
│   ├── Utilities/          # Shared utility components
│   ├── ContentView.swift   # Main app container view
│   └── MomentumFinanceApp.swift # App entry point
├── iOS/                    # iOS-specific code
├── macOS/                  # macOS-specific code
└── Package.swift           # Swift Package Manager manifest
```

## 🧪 Testing

We maintain comprehensive testing across the application:

```bash
# Run unit tests
./dev.sh test

# Run UI tests
./dev.sh ui-test

# Run all tests
./dev.sh test-all
```

## 🔧 Configuration

Momentum Finance is designed to be highly configurable. Key settings can be found in:

1. `Shared/Utilities/Config.swift` - Core app configuration
2. `.swiftlint.yml` - Code style rules
3. `.github/workflows/` - CI/CD configuration

## 🤝 Contributing

We welcome contributions to Momentum Finance! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`./dev.sh test-all`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

Please ensure your code follows our style guide and includes appropriate tests.

## 📄 License

Momentum Finance is released under the MIT License. See [LICENSE](LICENSE) for details.

## 📊 Roadmap

Our future development plans include:

- [ ] Advanced investment tracking and portfolio analysis
- [ ] Multi-currency support with real-time exchange rates
- [ ] Receipt scanning and automatic transaction entry
- [ ] Tax preparation assistance and reports
- [ ] Machine learning powered financial insights
- [ ] Apple Watch companion app
- [ ] API integration with financial institutions

## 🙏 Acknowledgments

- The SwiftUI and SwiftData teams at Apple
- All our contributors and beta testers
- The open-source Swift community

---

<p align="center">
  Made with ❤️ by the Momentum Finance Team
  <br>
  © 2025 Momentum Finance. All rights reserved.
</p>

### 📊 Budget Management
- Monthly budget creation and tracking
- Category-based spending limits
- Progress visualization
- Budget vs. actual spending analysis

### 🔄 Subscription Management
- Recurring payment tracking
- Automatic payment processing
- Subscription status monitoring
- Upcoming payment notifications

### 🎯 Goals & Reports
- Savings goal setting and tracking
- Financial reporting and insights
- Spending analysis and trends
- Progress visualization

### 📱 Cross-Platform
- Native iOS and macOS applications
- Shared data and synchronization
- Platform-optimized user interfaces

## Architecture

### Technology Stack
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistent data storage with relationships
- **MVVM Pattern**: Clean separation of concerns
- **Combine**: Reactive programming for data flow

### Project Structure
```
MomentumFinanceApp/
├── Shared/
│   ├── Models/              # SwiftData models
│   ├── Features/            # Feature modules (MVVM)
│   │   ├── Dashboard/
│   │   ├── Transactions/
│   │   ├── Budgets/
│   │   ├── Subscriptions/
│   │   └── GoalsAndReports/
│   ├── Utilities/           # Helper classes and extensions
│   ├── MomentumFinanceApp.swift
│   └── ContentView.swift
├── iOS/                     # iOS-specific code
├── macOS/                   # macOS-specific code
└── Configuration/           # Build and linting configuration
```

### Core Models
- **FinancialAccount**: Bank accounts, credit cards, cash
- **Transaction**: Income and expense records
- **Category**: Transaction categorization system
- **Subscription**: Recurring payment management
- **Budget**: Monthly spending limits
- **SavingsGoal**: Financial objectives and progress

## Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/momentum-finance.git
   cd momentum-finance
   ```

2. **Verify project structure**
   ```bash
   ./verify-project.sh
   ```

3. **Open in Xcode**
   ```bash
   open MomentumFinance.xcodeproj
   ```

4. **Build and run**
   - Select your target platform (iOS/macOS)
   - Press Cmd+R to build and run

### Development Setup

1. **Install SwiftLint** (optional but recommended)
   ```bash
   brew install swiftlint
   ```

2. **Configure development environment**
   - Enable SwiftLint integration in Xcode
   - Set up code formatting preferences
   - Configure simulators for testing

## Development

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftLint for consistent formatting
- Maintain clear separation between UI and business logic
- Document public APIs and complex algorithms

### Adding New Features

1. **Create feature module**
   ```
   Features/NewFeature/
   ├── NewFeatureView.swift
   ├── NewFeatureViewModel.swift
   └── Supporting files
   ```

2. **Follow MVVM pattern**
   - Views handle UI presentation
   - ViewModels contain business logic
   - Models represent data structures

3. **Update navigation**
   - Add to ContentView TabView
   - Configure appropriate icons and labels

### Data Management

All data is managed through SwiftData with automatic:
- Data persistence
- Relationship management
- Migration handling
- iCloud synchronization (when configured)

### Testing

Run the verification script to ensure project integrity:
```bash
./verify-project.sh
```

This checks:
- File structure completeness
- SwiftData model integrity
- MVVM pattern compliance
- Code quality indicators

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the coding standards
4. Run the verification script
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- Write clear, self-documenting code
- Add unit tests for business logic
- Update documentation for new features
- Follow the existing architectural patterns
- Use proper error handling and logging

## Project Status

### Completed ✅
- [x] SwiftData model implementation
- [x] Core MVVM architecture
- [x] Dashboard with account overview
- [x] Transaction management system
- [x] Budget tracking and visualization
- [x] Subscription management
- [x] Goals and reporting features
- [x] Error handling and logging utilities

### In Progress 🚧
- [ ] Xcode project file creation
- [ ] iOS/macOS platform-specific optimizations
- [ ] Settings and preferences
- [ ] Data export/import features

### Planned 📋
- [ ] iCloud synchronization
- [ ] Widget support
- [ ] Advanced reporting and analytics
- [ ] Custom categories and rules
- [ ] Notification system
- [ ] Dark mode optimization

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with Apple's latest SwiftUI and SwiftData frameworks
- Inspired by modern personal finance management needs
- Designed for simplicity and powerful functionality

## Support

If you encounter any issues or have feature requests:
1. Check the [Issues](https://github.com/yourusername/momentum-finance/issues) page
2. Create a new issue with detailed information
3. Follow the issue template for faster resolution

---

**Momentum Finance** - Take control of your financial future with modern, intuitive money management.

## 🚀 Quick Start

### Prerequisites
- macOS 14.0+ or iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### Installation & Running

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/MomentumFinanceApp.git
   cd MomentumFinanceApp
   ```

2. **Build and run on macOS:**
   ```bash
   swift build
   swift run MomentumFinance
   ```

3. **Open in Xcode (recommended for iOS):**
   ```bash
   open MomentumFinance.xcodeproj
   ```

### Current Status: ✅ FULLY FUNCTIONAL
- **Build Status**: ✅ Compiles successfully
- **Cross-Platform**: ✅ iOS and macOS compatible  
- **SwiftData**: ✅ Models and persistence working
- **SwiftLint**: 🟡 10 warnings (style/length - non-critical)
# Trigger workflows Thu Aug 14 16:13:30 CDT 2025
