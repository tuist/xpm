import Foundation
import TSCBasic

/// This model allows to configure Tuist.
public struct Config: Equatable, Hashable {
    /// Contains options related to the project generation.
    public enum GenerationOption: Hashable, Equatable {
        /// Name used for the Xcode project
        case xcodeProjectName(String)
        case organizationName(String)
        case developmentRegion(String)
        case swiftToolsVersion(String)
        case disableAutogeneratedSchemes
        case disableSynthesizedResourceAccessors
        case disableShowEnvironmentVarsInScriptPhases
        case enableCodeCoverage
        case templateMacros(IDETemplateMacros)
        case resolveDependenciesWithSystemScm
        /// Disables locking Swift packages. This can speed up generation but does increase risk if packages are not locked
        /// in their declarations.
        case disablePackageVersionLocking
    }

    /// List of `Plugin`s used to extend Tuist.
    public let plugins: [PluginLocation]

    /// Generation options.
    public let generationOptions: [GenerationOption]

    /// List of Xcode versions the project or set of projects is compatible with.
    public let compatibleXcodeVersions: CompatibleXcodeVersions

    /// Cloud configuration.
    public let cloud: Cloud?

    /// Cache configuration.
    public let cache: Cache?

    /// The path of the config file.
    public let path: AbsolutePath?

    /// Returns the default Tuist configuration.
    public static var `default`: Config {
        Config(compatibleXcodeVersions: .all, cloud: nil, cache: nil, plugins: [], generationOptions: [], path: nil)
    }

    /// Initializes the tuist cofiguration.
    ///
    /// - Parameters:
    ///   - compatibleXcodeVersions: List of Xcode versions the project or set of projects is compatible with.
    ///   - cloud: Cloud configuration.
    ///   - plugins: List of locations to a `Plugin` manifest.
    ///   - generationOptions: Generation options.
    ///   - path: The path of the config file.
    public init(
        compatibleXcodeVersions: CompatibleXcodeVersions,
        cloud: Cloud?,
        cache: Cache?,
        plugins: [PluginLocation],
        generationOptions: [GenerationOption],
        path: AbsolutePath?
    ) {
        self.compatibleXcodeVersions = compatibleXcodeVersions
        self.cloud = cloud
        self.cache = cache
        self.plugins = plugins
        self.generationOptions = generationOptions
        self.path = path
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(generationOptions)
        hasher.combine(cloud)
        hasher.combine(cache)
        hasher.combine(compatibleXcodeVersions)
    }
}
