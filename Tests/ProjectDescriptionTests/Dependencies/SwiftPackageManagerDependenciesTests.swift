import Foundation
import XCTest

@testable import ProjectDescription

final class SwiftPackageManagerDependenciesTests: XCTestCase {
    func test_swiftPackageManagerDependencies_codable() {
        let subject: SwiftPackageManagerDependencies = .swiftPackageManager(
            [
                .local(path: "Path/Path"),
                .remote(url: "Dependency3/Dependency3", requirement: .exact("4.5.6")),
            ],
            options: [
                .swiftToolsVersion("5.4.0"),
            ]
        )
        XCTAssertCodable(subject)
    }

    // MARK: - Carthage Options tests

    func test_swiftPackageManagerOptions_swiftToolsVersion_codable() throws {
        let subject: SwiftPackageManagerDependencies.Options = .swiftToolsVersion("1.2.3")
        XCTAssertCodable(subject)
    }
}
