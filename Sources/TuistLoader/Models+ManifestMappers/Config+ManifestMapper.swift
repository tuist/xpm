import Foundation
import ProjectDescription
import TSCBasic
import TuistCore
import TuistSupport

extension TuistCore.Config {
    /// Maps a ProjectDescription.Config instance into a TuistCore.Config model.
    /// - Parameters:
    ///   - manifest: Manifest representation of Tuist config.
    ///   - generatorPaths: Generator paths.
    static func from(manifest: ProjectDescription.Config) throws -> TuistCore.Config {
        let generationOptions = try manifest.generationOptions.map { try TuistCore.Config.GenerationOption.from(manifest: $0) }
        let compatibleXcodeVersions = TuistCore.CompatibleXcodeVersions.from(manifest: manifest.compatibleXcodeVersions)
        var cloud: TuistCore.Cloud?
        if let manifestCloud = manifest.cloud {
            cloud = try TuistCore.Cloud.from(manifest: manifestCloud)
        }
        return TuistCore.Config(compatibleXcodeVersions: compatibleXcodeVersions,
                                cloud: cloud,
                                generationOptions: generationOptions)
    }
}

extension TuistCore.Config.GenerationOption {
    /// Maps a ProjectDescription.Config.GenerationOptions instance into a TuistCore.Config.GenerationOptions model.
    /// - Parameters:
    ///   - manifest: Manifest representation of Tuist config generation options
    ///   - generatorPaths: Generator paths.
    static func from(manifest: ProjectDescription.Config.GenerationOptions) throws -> TuistCore.Config.GenerationOption {
        switch manifest {
        case let .xcodeProjectName(templateString):
            return .xcodeProjectName(templateString.description)
        case let .organizationName(name):
            return .organizationName(name)
        case .disableAutogeneratedSchemes:
            return .disableAutogeneratedSchemes
        }
    }
}
