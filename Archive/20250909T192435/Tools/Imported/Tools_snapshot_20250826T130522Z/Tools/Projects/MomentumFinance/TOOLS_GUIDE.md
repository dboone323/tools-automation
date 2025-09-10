# Development Tools Guide

This document provides instructions for using the development tools set up for the MomentumFinance project.

## Prerequisites

Before using these tools, make sure you have:

1. [Node.js and npm](https://nodejs.org/) (for Prettier)
2. [Docker](https://www.docker.com/products/docker-desktop) (for containerization)
3. [Visual Studio Code](https://code.visualstudio.com/) (recommended IDE)
4. [SwiftLint](https://github.com/realm/SwiftLint) (for Swift code linting)

## Setup

Run the setup script to install and configure all necessary tools:

```bash
./setup-tools.sh
```

This script will:
- Install Prettier and its Swift plugin
- Configure VS Code with recommended extensions
- Create necessary configuration files

## Code Formatting with Prettier

Prettier is configured to format Swift, JavaScript, JSON, and Markdown files.

### Format all files

```bash
npm run format
```

### Check formatting without modifying files

```bash
npm run format:check
```

## Linting with SwiftLint

SwiftLint is used to enforce Swift coding style and conventions.

### Run SwiftLint check

```bash
swiftlint --quiet
```

### Auto-fix SwiftLint issues

```bash
swiftlint --fix --quiet
```

## Containerization with Docker

Docker is configured to build and run the application in a container.

### Build the Docker image

```bash
docker build -t momentum-finance .
```

### Run the application in a container

```bash
docker run -it momentum-finance
```

### Using Docker Compose

```bash
docker-compose up --build
```

## Git Integration with GitLens

GitLens enhances the Git capabilities in VS Code:

- View inline Git blame annotations
- Explore Git repositories with powerful navigation
- Compare changes across branches, commits, and files
- See authorship through visualization

## VS Code Tasks

Several tasks are available in VS Code (press `Cmd+Shift+P` and type "Tasks"):

- `Build with Swift Package Manager`: Build the project
- `Run MomentumFinance App`: Run the app
- `Run SwiftLint Check`: Run SwiftLint
- `SwiftLint Auto-Fix`: Auto-fix SwiftLint issues
- `Format Code with Prettier`: Format code with Prettier
- `Build Docker Container`: Build the Docker image
- `Run Docker Container`: Run the app in a Docker container
- `Docker Compose Up`: Start the app using Docker Compose

## Debugging

Launch configurations are set up for debugging the app in VS Code:

- `Debug MomentumFinance`: Debug the app in debug mode
- `Release MomentumFinance`: Run the app in release mode

## Additional Notes

- The project is configured to format code on save in VS Code
- GitLens is configured to show blame annotations, current line information, and status bar information
- Docker is configured to build a containerized version of the app
