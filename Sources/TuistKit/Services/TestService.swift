import Foundation
import RxBlocking
import RxSwift
import TSCBasic
import struct TSCUtility.Version
import TuistAutomation
import TuistCache
import TuistCore
import TuistGraph
import TuistLoader
import TuistSupport

enum TestServiceError: FatalError {
    case schemeNotFound(scheme: String, existing: [String])
    case schemeWithoutTestableTargets(scheme: String)
    
    // Error description
    var description: String {
        switch self {
        case let .schemeNotFound(scheme, existing):
            return "Couldn't find scheme \(scheme). The available schemes are: \(existing.joined(separator: ", "))."
        case let .schemeWithoutTestableTargets(scheme):
            return "The scheme \(scheme) cannot be built because it contains no buildable targets."
        }
    }
    
    // Error type
    var type: ErrorType {
        switch self {
        case .schemeNotFound:
            return .abort
        case .schemeWithoutTestableTargets:
            return .abort
        }
    }
}

final class TestService {
    /// Project generator
    private let generator: Generating
    private let xcodebuildController: XcodeBuildControlling
    private let buildGraphInspector: BuildGraphInspecting
    private let simulatorController: SimulatorControlling
    
    private let temporaryDirectory: TemporaryDirectory
    private let testsCacheTemporaryDirectory: TemporaryDirectory
    
    convenience init() throws {
        let temporaryDirectory = try TemporaryDirectory(removeTreeOnDeinit: true)
        let testsCacheTemporaryDirectory = try TemporaryDirectory(removeTreeOnDeinit: true)
        self.init(
            temporaryDirectory: temporaryDirectory,
            testsCacheTemporaryDirectory: testsCacheTemporaryDirectory,
            generator: Generator(
                projectMapperProvider: AutomationProjectMapperProvider(),
                graphMapperProvider: AutomationGraphMapperProvider(
                    testsCacheDirectory: testsCacheTemporaryDirectory.path
                ),
                workspaceMapperProvider: AutomationWorkspaceMapperProvider(
                    workspaceDirectory: temporaryDirectory.path
                ),
                manifestLoaderFactory: ManifestLoaderFactory()
            )
        )
    }
    
    init(
        temporaryDirectory: TemporaryDirectory,
        testsCacheTemporaryDirectory: TemporaryDirectory,
        generator: Generating,
        xcodebuildController: XcodeBuildControlling = XcodeBuildController(),
        buildGraphInspector: BuildGraphInspecting = BuildGraphInspector(),
        simulatorController: SimulatorControlling = SimulatorController()
    ) {
        self.temporaryDirectory = temporaryDirectory
        self.testsCacheTemporaryDirectory = testsCacheTemporaryDirectory
        self.generator = generator
        self.xcodebuildController = xcodebuildController
        self.buildGraphInspector = buildGraphInspector
        self.simulatorController = simulatorController
    }
    
    func run(
        schemeName: String?,
        clean: Bool,
        configuration: String?,
        path: AbsolutePath,
        deviceName: String?,
        osVersion: String?
    ) throws {
        logger.notice("Generating project for testing", metadata: .section)
        let graph: Graph = try generator.generateWithGraph(
            path: path,
            projectOnly: false
        ).1
        let version = osVersion?.version()
        
        let testableSchemes = buildGraphInspector.testableSchemes(graph: graph)
        logger.log(
            level: .debug,
            "Found the following testable schemes: \(testableSchemes.map(\.name).joined(separator: ", "))"
        )
        
        let testSchemes: [Scheme]
        if let schemeName = schemeName {
            guard
                let scheme = testableSchemes.first(where: { $0.name == schemeName })
            else {
                throw TestServiceError.schemeNotFound(
                    scheme: schemeName,
                    existing: testableSchemes.map(\.name)
                )
            }
            testSchemes = [scheme]
        } else {
            testSchemes = buildGraphInspector.projectSchemes(graph: graph)
            guard
                !testSchemes.isEmpty
            else {
                throw TestServiceError.schemeNotFound(
                    scheme: "\(graph.workspace.name)-Project",
                    existing: testableSchemes.map(\.name)
                )
            }
        }
        
        try testSchemes.forEach { testScheme in
            try self.testScheme(
                scheme: testScheme,
                graph: graph,
                path: path,
                clean: clean,
                configuration: configuration,
                version: version,
                deviceName: deviceName
            )
        }
        
        if !FileHandler.shared.exists(
            Environment.shared.testsCacheDirectory
        ) {
            try FileHandler.shared.createFolder(Environment.shared.testsCacheDirectory)
        }
        
        try FileHandler.shared
            .contentsOfDirectory(testsCacheTemporaryDirectory.path)
            .forEach {
                try FileHandler.shared.move(
                    from: $0,
                    to: Environment.shared.testsCacheDirectory.appending(component: $0.basename)
                )
            }
        
        logger.log(level: .notice, "The project tests ran successfully", metadata: .success)
    }
    
    // MARK: - Helpers
    
    private func testScheme(
        scheme: Scheme,
        graph: Graph,
        path _: AbsolutePath,
        clean: Bool,
        configuration: String?,
        version: Version?,
        deviceName: String?
    ) throws {
        logger.log(level: .notice, "Testing scheme \(scheme.name)", metadata: .section)
        guard let buildableTarget = buildGraphInspector.testableTarget(scheme: scheme, graph: graph) else {
            throw TestServiceError.schemeWithoutTestableTargets(scheme: scheme.name)
        }
        
        let destination = try findDestination(
            buildableTarget: buildableTarget.target,
            scheme: scheme,
            graph: graph,
            version: version,
            deviceName: deviceName
        )
        
        _ = try xcodebuildController.test(
            .workspace(graph.workspace.xcWorkspacePath),
            scheme: scheme.name,
            clean: clean,
            destination: destination,
            derivedDataPath: nil,
            arguments: buildGraphInspector.buildArguments(
                target: buildableTarget.target,
                configuration: configuration,
                skipSigning: true
            )
        )
        .printFormattedOutput()
        .toBlocking()
        .last()
    }
    
    private func findDestination(
        buildableTarget: Target,
        scheme: Scheme,
        graph: Graph,
        version: Version?,
        deviceName: String?
    ) throws -> XcodeBuildDestination {
        switch buildableTarget.platform {
        case .iOS, .tvOS, .watchOS:
            let minVersion: Version?
            if let deploymentTarget = buildableTarget.deploymentTarget {
                minVersion = deploymentTarget.version.version()
            } else {
                minVersion = scheme.targetDependencies()
                    .compactMap { graph.findTargetNode(path: $0.projectPath, name: $0.name) }
                    .flatMap {
                        $0.targetDependencies
                            .compactMap { $0.target.deploymentTarget?.version }
                    }
                    .compactMap { $0.version() }
                    .sorted()
                    .first
            }
            let deviceAndRuntime = try simulatorController.findAvailableDevice(
                platform: buildableTarget.platform,
                version: version,
                minVersion: minVersion,
                deviceName: deviceName
            )
            .toBlocking()
            .single()
            return .device(deviceAndRuntime.device.udid)
        case .macOS:
            return .mac
        }
    }
}
