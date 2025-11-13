// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PlannerApp",
    dependencies: [
        .package(name: "shared-kit", path: "../shared-kit"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.5.0"),
    ]
)
