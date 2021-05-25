import Foundation

public typealias TuistConfig = Config

/// This model allows to configure Tuist.
public struct Config: Codable, Equatable {
    /// Contains options related to the project generation.
    public enum GenerationOptions: Codable, Equatable {
        /// Tuist generates the project with the specific name on disk instead of using the project name.
        case xcodeProjectName(TemplateString)

        /// Tuist generates the project with the specific organization name.
        case organizationName(String)

        /// Tuist generates the project with the specific development region.
        case developmentRegion(String)

        /// Tuist generates the project only with custom specified schemes, autogenerated default
        case disableAutogeneratedSchemes

        /// Tuist does not synthesize resource accessors
        case disableSynthesizedResourceAccessors

        /// Tuist disables echoing the ENV in shell script build phases
        case disableShowEnvironmentVarsInScriptPhases

        /// When passed, Tuist will enable code coverage for autogenerated default schemes
        case enableCodeCoverage

        /// When passed, Xcode will resolve its Package Manager dependencies using the system-defined
        /// accounts (e.g. git) instead of the Xcode-defined accounts
        case resolveDependenciesWithSystemScm

        /// Disables locking Swift packages. This can speed up generation but does increase risk if packages are not locked
        /// in their declarations.
        case disablePackageVersionLocking
    }

    /// Generation options.
    public let generationOptions: [GenerationOptions]

    /// List of Xcode versions that the project supports.
    public let compatibleXcodeVersions: CompatibleXcodeVersions

    /// List of `Plugin`s used to extend Tuist.
    public let plugins: [PluginLocation]

    /// Lab configuration.
    public let lab: Lab?

    /// Cache configuration.
    public let cache: Cache?
    
    /// The specified version of Swift that will be used by Tuist.
    /// When `nil` is passed then Tuist will use the environment’s version.
    public let swiftVersion: Version?

    /// Initializes the tuist configuration.
    ///
    /// - Parameters:
    ///   - compatibleXcodeVersions: List of Xcode versions the project is compatible with.
    ///   - lab: Lab configuration.
    ///   - cache: Cache configuration.
    ///   - swiftVersion: The specified version of Swift that will be used by Tuist.
    ///   - plugins: A list of plugins to extend Tuist.
    ///   - generationOptions: List of options to use when generating the project.
    public init(
        compatibleXcodeVersions: CompatibleXcodeVersions = .all,
        lab: Lab? = nil,
        cache: Cache? = nil,
        swiftVersion: Version? = nil,
        plugins: [PluginLocation] = [],
        generationOptions: [GenerationOptions]
    ) {
        self.compatibleXcodeVersions = compatibleXcodeVersions
        self.plugins = plugins
        self.generationOptions = generationOptions
        self.lab = lab
        self.cache = cache
        self.swiftVersion = swiftVersion
        dumpIfNeeded(self)
    }
}

extension Config.GenerationOptions {
    enum CodingKeys: String, CodingKey {
        case xcodeProjectName
        case organizationName
        case developmentRegion
        case disableAutogeneratedSchemes
        case disableSynthesizedResourceAccessors
        case disableShowEnvironmentVarsInScriptPhases
        case enableCodeCoverage
        case resolveDependenciesWithSystemScm
        case disablePackageVersionLocking
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.allKeys.contains(.xcodeProjectName), try container.decodeNil(forKey: .xcodeProjectName) == false {
            var associatedValues = try container.nestedUnkeyedContainer(forKey: .xcodeProjectName)
            let templateProjectName = try associatedValues.decode(TemplateString.self)
            self = .xcodeProjectName(templateProjectName)
        } else if container.allKeys.contains(.organizationName), try container.decodeNil(forKey: .organizationName) == false {
            var associatedValues = try container.nestedUnkeyedContainer(forKey: .organizationName)
            let organizationName = try associatedValues.decode(String.self)
            self = .organizationName(organizationName)
        } else if container.allKeys.contains(.developmentRegion), try container.decodeNil(forKey: .developmentRegion) == false {
            var associatedValues = try container.nestedUnkeyedContainer(forKey: .developmentRegion)
            let developmentRegion = try associatedValues.decode(String.self)
            self = .developmentRegion(developmentRegion)
        } else if container.allKeys.contains(.disableAutogeneratedSchemes), try container.decode(Bool.self, forKey: .disableAutogeneratedSchemes) {
            self = .disableAutogeneratedSchemes
        } else if container.allKeys.contains(.disableSynthesizedResourceAccessors),
            try container.decode(Bool.self, forKey: .disableSynthesizedResourceAccessors)
        {
            self = .disableSynthesizedResourceAccessors
        } else if container.allKeys.contains(.disableShowEnvironmentVarsInScriptPhases),
            try container.decode(Bool.self, forKey: .disableShowEnvironmentVarsInScriptPhases)
        {
            self = .disableShowEnvironmentVarsInScriptPhases
        } else if container.allKeys.contains(.enableCodeCoverage), try container.decode(Bool.self, forKey: .enableCodeCoverage) {
            self = .enableCodeCoverage
        } else if container.allKeys.contains(.disablePackageVersionLocking), try container.decode(Bool.self, forKey: .disablePackageVersionLocking) {
            self = .disablePackageVersionLocking
        } else if container.allKeys.contains(.resolveDependenciesWithSystemScm),
            try container.decode(Bool.self, forKey: .resolveDependenciesWithSystemScm)
        {
            self = .resolveDependenciesWithSystemScm
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown enum case"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .xcodeProjectName(templateProjectName):
            var associatedValues = container.nestedUnkeyedContainer(forKey: .xcodeProjectName)
            try associatedValues.encode(templateProjectName)
        case let .organizationName(name):
            var associatedValues = container.nestedUnkeyedContainer(forKey: .organizationName)
            try associatedValues.encode(name)
        case let .developmentRegion(developmentRegion):
            var associatedValues = container.nestedUnkeyedContainer(forKey: .developmentRegion)
            try associatedValues.encode(developmentRegion)
        case .disableAutogeneratedSchemes:
            try container.encode(true, forKey: .disableAutogeneratedSchemes)
        case .disableSynthesizedResourceAccessors:
            try container.encode(true, forKey: .disableSynthesizedResourceAccessors)
        case .disableShowEnvironmentVarsInScriptPhases:
            try container.encode(true, forKey: .disableShowEnvironmentVarsInScriptPhases)
        case .enableCodeCoverage:
            try container.encode(true, forKey: .enableCodeCoverage)
        case .resolveDependenciesWithSystemScm:
            try container.encode(true, forKey: .resolveDependenciesWithSystemScm)
        case .disablePackageVersionLocking:
            try container.encode(true, forKey: .disablePackageVersionLocking)
        }
    }
}
