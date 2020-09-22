import Foundation
import XCTest
@testable import ProjectDescription

final class ConfigTests: XCTestCase {
    func test_config_toJSON() throws {
        let config = Config(cloud: Cloud(url: "https://cloud.tuist.io", projectId: "123", options: [.insights]),
                            generationOptions: [
                                .xcodeProjectName("someprefix-\(.projectName)"),
                                .organizationName("TestOrg"),
                                .disableAutogeneratedSchemes,
                                .disableSynthesizedResourceAccessors,
                                .disableShowEnvironmentVarsInScriptPhases,
                            ])

        XCTAssertCodable(config)
    }

    func test_config_toJSON_withAutogeneratedSchemes() throws {
        let config = Config(cloud: Cloud(url: "https://cloud.tuist.io", projectId: "123", options: [.insights]),
                            generationOptions: [
                                .xcodeProjectName("someprefix-\(.projectName)"),
                                .organizationName("TestOrg"),
                            ])

        XCTAssertCodable(config)
    }
}
