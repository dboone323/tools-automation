// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "CodingReviewer",
    dependencies: [
        .package(name: "shared-kit", path: "../shared-kit"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.6.0"),
    ]
)
