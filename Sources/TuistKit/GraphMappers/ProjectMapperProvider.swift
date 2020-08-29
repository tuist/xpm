import Foundation
import TuistCore
import TuistGenerator
import TuistLoader
import TuistSigning

/// It defines an interface for providing the project mappers to be used for a specific configuration.
protocol ProjectMapperProviding {
    /// Returns a list of mappers to be used for a specific configuration.
    /// - Parameter config: Project's configuration.
    func mapper(config: Config) -> ProjectMapping
}

class ProjectMapperProvider: ProjectMapperProviding {
    func mapper(config: Config) -> ProjectMapping {
        var mappers: [ProjectMapping] = []

        // Auto-generation of schemes
        if !config.generationOptions.contains(.disableAutogeneratedSchemes) {
            mappers.append(AutogeneratedSchemesProjectMapper())
        }

        // Info Plist
        mappers.append(DeleteDerivedDirectoryProjectMapper())
        mappers.append(GenerateInfoPlistProjectMapper())
        
        // Namespace generator
        if !config.generationOptions.contains(.disableSynthesizedResourceAccessors) {
            mappers.append(SynthesizedResourceInterfaceProjectMapper())
        }
        
        // Support for resources in libraries
        mappers.append(ResourcesProjectMapper())

        // Project name mapper
        mappers.append(ProjectNameAndOrganizationMapper(config: config))

        // Signing
        mappers.append(SigningMapper())

        return SequentialProjectMapper(mappers: mappers)
    }
}
