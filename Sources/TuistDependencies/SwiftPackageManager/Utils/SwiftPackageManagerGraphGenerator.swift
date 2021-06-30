import Foundation
import ProjectDescription
import TSCBasic
import TSCUtility
import TuistCore
import TuistGraph
import TuistSupport

// MARK: - Swift Package Manager Graph Generator Errors

enum SwiftPackageManagerGraphGeneratorError: FatalError, Equatable {
    /// Thrown when no supported platforms are found for a package.
    case noSupportedPlatforms(name: String, configured: Set<ProjectDescription.Platform>, package: Set<ProjectDescription.Platform>)

    /// Thrown when `PackageInfo.Target.Dependency.byName` dependency cannot be resolved.
    case unknownByNameDependency(String)

    /// Thrown when `PackageInfo.Platform` name cannot be mapped to a `DeploymentTarget`.
    case unknownPlatform(String)

    /// Thrown when `PackageInfo.Target.Dependency.product` dependency cannot be resolved.
    case unknownProductDependency(String, String)

    /// Thrown when `WorkspaceState.Dependency.Kind` is not one of the expected values.
    case unsupportedDependencyKind(String)

    /// Thrown when unsupported `PackageInfo.Target.TargetBuildSettingDescription` `Tool`/`SettingName` pair is found.
    case unsupportedSetting(PackageInfo.Target.TargetBuildSettingDescription.Tool, PackageInfo.Target.TargetBuildSettingDescription.SettingName)

    /// Error type.
    var type: ErrorType {
        switch self {
        case .noSupportedPlatforms, .unknownByNameDependency, .unknownPlatform, .unknownProductDependency, .unsupportedDependencyKind,
             .unsupportedSetting:
            return .abort
        }
    }

    /// Error description.
    var description: String {
        switch self {
        case let .noSupportedPlatforms(name, configured, package):
            return "No supported platform found for the \(name) dependency. Configured: \(configured), package: \(package)."
        case let .unknownByNameDependency(name):
            return "The package associated to the \(name) dependency cannot be found."
        case let .unknownPlatform(platform):
            return "The \(platform) platform is not supported."
        case let .unknownProductDependency(name, package):
            return "The product \(name) of the package \(package) cannot be found."
        case let .unsupportedDependencyKind(name):
            return "The dependency kind \(name) is not supported."
        case let .unsupportedSetting(tool, setting):
            return "The \(tool) and \(setting) pair is not a supported setting."
        }
    }
}

// MARK: - Swift Package Manager Graph Generator

/// A protocol that defines an interface to generate the `DependenciesGraph` for the `SwiftPackageManager` dependencies.
public protocol SwiftPackageManagerGraphGenerating {
    /// Generates the `DependenciesGraph` for the `SwiftPackageManager` dependencies.
    /// - Parameter path: The path to the directory that contains the `checkouts` directory where `SwiftPackageManager` installed dependencies.
    /// - Parameter productTypes: The custom `Product` types to be used for SPM targets.
    /// - Parameter platforms: The supported platforms.
    func generate(
        at path: AbsolutePath,
        productTypes: [String: TuistGraph.Product],
        platforms: Set<TuistGraph.Platform>
    ) throws -> TuistCore.DependenciesGraph
}

public final class SwiftPackageManagerGraphGenerator: SwiftPackageManagerGraphGenerating {
    private let swiftPackageManagerController: SwiftPackageManagerControlling

    public init(
        swiftPackageManagerController: SwiftPackageManagerControlling = SwiftPackageManagerController()
    ) {
        self.swiftPackageManagerController = swiftPackageManagerController
    }

    public func generate(
        at path: AbsolutePath,
        productTypes: [String: TuistGraph.Product],
        platforms: Set<TuistGraph.Platform>
    ) throws -> TuistCore.DependenciesGraph {
        let artifactsFolder = path.appending(component: "artifacts")
        let checkoutsFolder = path.appending(component: "checkouts")
        let workspacePath = path.appending(component: "workspace-state.json")

        let workspaceState = try JSONDecoder().decode(WorkspaceState.self, from: try FileHandler.shared.readFile(workspacePath))
        let packageInfos: [(name: String, folder: AbsolutePath, artifactsFolder: AbsolutePath, info: PackageInfo)]
        packageInfos = try workspaceState.object.dependencies.map { dependency in
            let name = dependency.packageRef.name
            let packageFolder: AbsolutePath
            switch dependency.packageRef.kind {
            case "remote":
                packageFolder = checkoutsFolder.appending(component: name)
            case "local":
                packageFolder = AbsolutePath(dependency.packageRef.path)
            default:
                throw SwiftPackageManagerGraphGeneratorError.unsupportedDependencyKind(dependency.packageRef.kind)
            }

            let packageInfo = try swiftPackageManagerController.loadPackageInfo(at: packageFolder)
            return (
                name: name,
                folder: packageFolder,
                artifactsFolder: artifactsFolder.appending(component: name),
                info: packageInfo
            )
        }

        let productToPackage: [String: String] = packageInfos.reduce(into: [:]) { result, packageInfo in
            packageInfo.info.products.forEach { result[$0.name] = packageInfo.name }
        }

        let externalDependencies: [String: [ProjectDescription.TargetDependency]] = packageInfos.reduce(into: [:]) { result, packageInfo in
            packageInfo.info.products.forEach { product in
                result[product.name] = product.targets.map { .project(target: $0, path: Path(packageInfo.folder.pathString)) }
            }
        }
        let packageInfoDictionary = Dictionary(uniqueKeysWithValues: packageInfos.map { ($0.name, $0.info) })
        let externalProjects: [Path: ProjectDescription.Project] = try packageInfos.reduce(into: [:]) { result, packageInfo in
            let artifactsFolder = artifactsFolder.appending(component: packageInfo.name)
            let targetDependencyToFramework: [String: Path] = packageInfo.info.targets.reduce(into: [:]) { result, target in
                guard target.type == .binary else { return }

                result[target.name] = Path(artifactsFolder.appending(component: "\(target.name).xcframework").pathString)
            }

            let manifest = try ProjectDescription.Project.from(
                packageInfo: packageInfo.info,
                packageInfos: packageInfoDictionary,
                name: packageInfo.name,
                folder: packageInfo.folder,
                productTypes: productTypes,
                platforms: platforms,
                productToPackage: productToPackage,
                targetDependencyToFramework: targetDependencyToFramework
            )
            result[Path(packageInfo.folder.pathString)] = manifest
        }

        return DependenciesGraph(externalDependencies: externalDependencies, externalProjects: externalProjects)
    }
}

extension ProjectDescription.Project {
    fileprivate static func from(
        packageInfo: PackageInfo,
        packageInfos: [String: PackageInfo],
        name: String,
        folder: AbsolutePath,
        productTypes: [String: TuistGraph.Product],
        platforms: Set<TuistGraph.Platform>,
        productToPackage: [String: String],
        targetDependencyToFramework: [String: Path]
    ) throws -> Self {
        let targets = try packageInfo.targets.compactMap { target in
            try Target.from(
                target: target,
                packageName: name,
                packageInfo: packageInfo,
                packageInfos: packageInfos,
                folder: folder,
                productTypes: productTypes,
                platforms: platforms,
                productToPackage: productToPackage,
                targetDependencyToFramework: targetDependencyToFramework
            )
        }
        return ProjectDescription.Project(
            name: name,
            targets: targets,
            resourceSynthesizers: []
        )
    }
}

extension ProjectDescription.Target {
    fileprivate static func from(
        target: PackageInfo.Target,
        packageName: String,
        packageInfo: PackageInfo,
        packageInfos: [String: PackageInfo],
        folder: AbsolutePath,
        productTypes: [String: TuistGraph.Product],
        platforms: Set<TuistGraph.Platform>,
        productToPackage: [String: String],
        targetDependencyToFramework: [String: Path]
    ) throws -> Self? {
        guard target.type == .regular else {
            logger.debug("Target \(target.name) of type \(target.type) ignored")
            return nil
        }

        guard let product = ProjectDescription.Product.from(name: target.name, packageInfo: packageInfo, productTypes: productTypes) else {
            logger.debug("Target \(target.name) ignored by product type")
            return nil
        }

        let path = folder.appending(RelativePath(target.path ?? "Sources/\(target.name)"))

        let platform = try ProjectDescription.Platform.from(configured: platforms, package: packageInfo.platforms, packageName: packageName)
        let deploymentTarget = try ProjectDescription.DeploymentTarget.from(configured: platforms, package: packageInfo.platforms, packageName: packageName)
        let sources = SourceFilesList.from(sources: target.sources, path: path, excluding: target.exclude)
        let resources = ResourceFileElements.from(resources: target.resources, path: path)
        let dependencies = try ProjectDescription.TargetDependency.from(
          packageInfo: packageInfo,
          packageInfos: packageInfos,
          dependencies: target.dependencies,
          settings: target.settings,
          packageName: packageName,
          productToPackage: productToPackage,
          targetDependencyToFramework: targetDependencyToFramework
        )
        let settings = try Settings.from(settings: target.settings)

        return .init(
            name: target.name,
            platform: platform,
            product: product,
            bundleId: target.name,
            deploymentTarget: deploymentTarget,
            infoPlist: .default,
            sources: sources,
            resources: resources,
            dependencies: dependencies,
            settings: settings
        )
    }
}

extension ProjectDescription.Platform {
    fileprivate static func from(
        configured: Set<TuistGraph.Platform>,
        package: [PackageInfo.Platform],
        packageName: String
    ) throws -> Self {
        let configuredPlatforms = Set(configured.map(\.descriptionPlatform))
        let packagePlatform = Set(package.isEmpty ? ProjectDescription.Platform.allCases : try package.map { try $0.descriptionPlatform() })
        let validPlatforms = configuredPlatforms.intersection(packagePlatform)

        #warning("Handle multiple platforms when supported in ProjectDescription.Target")
        if validPlatforms.contains(.iOS) {
            return .iOS
        }

        guard let platform = validPlatforms.first else {
            throw SwiftPackageManagerGraphGeneratorError.noSupportedPlatforms(
                name: packageName,
                configured: configuredPlatforms,
                package: packagePlatform
            )
        }

        return platform
    }
}

extension ProjectDescription.DeploymentTarget {
    fileprivate static func from(
        configured: Set<TuistGraph.Platform>,
        package: [PackageInfo.Platform],
        packageName: String
    ) throws -> Self? {
        guard !package.isEmpty else {
            return nil
        }

        let platform = try ProjectDescription.Platform.from(configured: configured, package: package, packageName: packageName)
        switch platform {
        case .iOS:
            let packagePlatform = package.first { $0.platformName == "ios" }!
            return .iOS(targetVersion: packagePlatform.version, devices: [.iphone, .ipad, .mac])
        case .macOS:
            let packagePlatform = package.first { $0.platformName == "macos" }!
            return .macOS(targetVersion: packagePlatform.version)
        case .watchOS:
            let packagePlatform = package.first { $0.platformName == "watchos" }!
            return .watchOS(targetVersion: packagePlatform.version)
        case .tvOS:
            let packagePlatform = package.first { $0.platformName == "tvos" }!
            return .tvOS(targetVersion: packagePlatform.version)
        }
    }
}

extension ProjectDescription.Product {
    fileprivate static func from(name: String, packageInfo: PackageInfo, productTypes: [String: TuistGraph.Product]) -> Self? {
        if let productType = productTypes[name] {
            return ProjectDescription.Product.from(product: productType)
        }

        return packageInfo.products
            .filter { $0.targets.contains(name) }
            .compactMap {
                switch $0.type {
                case let .library(type):
                    switch type {
                    case .static, .automatic:
                        return .staticFramework
                    case .dynamic:
                        return .framework
                    }
                case .executable, .plugin, .test:
                    return nil
                }
            }
            .first ?? .staticFramework
    }
}

extension SourceFilesList {
    fileprivate static func from(sources: [String]?, path: AbsolutePath, excluding: [String]) -> Self? {
        let sourcesPaths: [AbsolutePath]
        if let customSources = sources {
            sourcesPaths = customSources.map { path.appending(RelativePath($0)) }
        } else {
            sourcesPaths = [path]
        }
        guard !sourcesPaths.isEmpty else { return nil }
        return .init(
            globs: sourcesPaths.map { absolutePath -> ProjectDescription.SourceFileGlob in
                let glob = absolutePath.extension != nil ? absolutePath : absolutePath.appending(component: "**")
                return .init(
                    Path(glob.pathString),
                    excluding: excluding.map { Path($0) }
                )
            }
        )
    }
}

extension ResourceFileElements {
    fileprivate static func from(resources: [PackageInfo.Target.Resource], path: AbsolutePath) -> Self? {
        let resourcesPaths = resources.map { path.appending(RelativePath($0.path)) }
        guard !resourcesPaths.isEmpty else { return nil }
        return .init(resources: resourcesPaths.map { absolutePath in
            let absolutePathGlob = absolutePath.extension != nil ? absolutePath : absolutePath.appending(component: "**")
            return .glob(pattern: Path(absolutePathGlob.pathString))
        })
    }
}

extension ProjectDescription.TargetDependency {
    fileprivate static func from(
        packageInfo: PackageInfo,
        packageInfos: [String: PackageInfo],
        dependencies: [PackageInfo.Target.Dependency],
        settings: [PackageInfo.Target.TargetBuildSettingDescription.Setting],
        packageName _: String,
        productToPackage: [String: String],
        targetDependencyToFramework: [String: Path]
    ) throws -> [Self] {
        let targetDependencies = try dependencies.flatMap { dependency -> [ProjectDescription.TargetDependency] in
            switch dependency {
            case let .target(name, _):
                return [.target(name: name)]
            case let .product(name, package, _):
                guard let targets = packageInfos[package]?.products.first(where: { $0.name == name })?.targets else {
                    throw SwiftPackageManagerGraphGeneratorError.unknownProductDependency(name, package)
                }
                return targets.map { .project(target: $0, path: Path(RelativePath("../\(package)").pathString)) }
            case let .byName(name, _):
                if packageInfo.targets.contains(where: { $0.name == name }) {
                    if let framework = targetDependencyToFramework[name] {
                        return [.xcframework(path: framework)]
                    } else {
                        return [.target(name: name)]
                    }
                } else if let package = productToPackage[name] {
                    guard let targets = packageInfos[package]?.products.first(where: { $0.name == name })?.targets else {
                        throw SwiftPackageManagerGraphGeneratorError.unknownProductDependency(name, package)
                    }
                    return targets.map { .project(target: $0, path: Path(RelativePath("../\(package)").pathString)) }
                } else {
                    throw SwiftPackageManagerGraphGeneratorError.unknownByNameDependency(name)
                }
            }
        }

        let linkerDependencies: [ProjectDescription.TargetDependency] = settings.compactMap { setting in
            switch (setting.tool, setting.name) {
            case (.linker, .linkedFramework):
                return .sdk(name: "\(setting.value[0]).framework", status: .required)
            case (.linker, .linkedLibrary):
                return .sdk(name: "\(setting.value[0]).tbd", status: .required)
            case (.c, _), (.cxx, _), (.swift, _), (.linker, .headerSearchPath), (.linker, .define), (.linker, .unsafeFlags):
                return nil
            }
        }

        return targetDependencies + linkerDependencies
    }
}

extension ProjectDescription.Settings {
    // swiftlint:disable:next function_body_length
    fileprivate static func from(
        settings: [PackageInfo.Target.TargetBuildSettingDescription.Setting]
    ) throws -> Self? {
        var headerSearchPaths: [String] = []
        var defines: [String: String] = [:]
        var swiftDefines: [String] = []
        var cFlags: [String] = []
        var cxxFlags: [String] = []
        var swiftFlags: [String] = []

        try settings.forEach { setting in
            switch (setting.tool, setting.name) {
            case (.c, .headerSearchPath), (.cxx, .headerSearchPath):
                headerSearchPaths.append(setting.value[0])
            case (.c, .define), (.cxx, .define):
                let (name, value) = setting.extractDefine
                defines[name] = value
            case (.c, .unsafeFlags):
                cFlags.append(contentsOf: setting.value)
            case (.cxx, .unsafeFlags):
                cxxFlags.append(contentsOf: setting.value)
            case (.swift, .define):
                swiftDefines.append(setting.value[0])
            case (.swift, .unsafeFlags):
                swiftFlags.append(contentsOf: setting.value)

            case (.linker, .linkedFramework), (.linker, .linkedLibrary):
                // Handled as dependency
                return

            case (.c, .linkedFramework), (.c, .linkedLibrary), (.cxx, .linkedFramework), (.cxx, .linkedLibrary),
                 (.swift, .headerSearchPath), (.swift, .linkedFramework), (.swift, .linkedLibrary),
                 (.linker, .headerSearchPath), (.linker, .define), (.linker, .unsafeFlags):
                throw SwiftPackageManagerGraphGeneratorError.unsupportedSetting(setting.tool, setting.name)
            }
        }

        var settingsDictionary: ProjectDescription.SettingsDictionary = [:]
        if !headerSearchPaths.isEmpty {
            settingsDictionary["HEADER_SEARCH_PATHS"] = .array(headerSearchPaths)
        }
        if !defines.isEmpty {
            let sortedDefines = defines.sorted { $0.key < $1.key }
            settingsDictionary["GCC_PREPROCESSOR_DEFINITIONS"] = .array(sortedDefines.map { key, value in "\(key)=\(value)" })
        }
        if !swiftDefines.isEmpty {
            settingsDictionary["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = .array(swiftDefines)
        }
        if !cFlags.isEmpty {
            settingsDictionary["OTHER_CFLAGS"] = .array(cFlags)
        }
        if !cxxFlags.isEmpty {
            settingsDictionary["OTHER_CPLUSPLUSFLAGS"] = .array(cxxFlags)
        }
        if !swiftFlags.isEmpty {
            settingsDictionary["OTHER_SWIFT_FLAGS"] = .array(swiftFlags)
        }

        return .init(base: settingsDictionary)
    }
}

extension PackageInfo.Target.TargetBuildSettingDescription.Setting {
    fileprivate var extractDefine: (name: String, value: String) {
        let define = value[0]
        if define.contains("=") {
            let split = define.split(separator: "=", maxSplits: 1)
            return (name: String(split[0]), value: String(split[1]))
        } else {
            return (name: define, value: "1")
        }
    }
}

extension TuistGraph.Platform {
    fileprivate var descriptionPlatform: ProjectDescription.Platform {
        switch self {
        case .iOS:
            return .iOS
        case .macOS:
            return .macOS
        case .tvOS:
            return .tvOS
        case .watchOS:
            return .watchOS
        }
    }
}

extension PackageInfo.Platform {
    fileprivate func descriptionPlatform() throws -> ProjectDescription.Platform {
        switch platformName {
        case "ios":
            return .iOS
        case "macos":
            return .macOS
        case "tvos":
            return .tvOS
        case "watchos":
            return .watchOS
        default:
            throw SwiftPackageManagerGraphGeneratorError.unknownPlatform(platformName)
        }
    }
}

extension ProjectDescription.Product {
    fileprivate static func from(product: TuistGraph.Product) -> Self {
        switch product {
        case .app:
            return .app
        case .staticLibrary:
            return .staticLibrary
        case .dynamicLibrary:
            return .dynamicLibrary
        case .framework:
            return .framework
        case .staticFramework:
            return .staticFramework
        case .unitTests:
            return .unitTests
        case .uiTests:
            return .uiTests
        case .bundle:
            return .bundle
        case .commandLineTool:
            return .commandLineTool
        case .appExtension:
            return .appExtension
        case .watch2App:
            return .watch2App
        case .watch2Extension:
            return .watch2Extension
        case .tvTopShelfExtension:
            return .tvTopShelfExtension
        case .messagesExtension:
            return .messagesExtension
        case .stickerPackExtension:
            return .stickerPackExtension
        case .appClip:
            return .appClip
        }
    }
}
