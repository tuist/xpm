import Foundation
import TuistCore
import TuistGraph

/// A project mapper that auto-generates schemes for each of the targets of the `Project`
/// if the user hasn't already defined schemes for those.
public final class AutogeneratedSchemesProjectMapper: ProjectMapping {
    private let enableCodeCoverage: Bool

    // MARK: - Init

    public init(enableCodeCoverage: Bool) {
        self.enableCodeCoverage = enableCodeCoverage
    }

    // MARK: - ProjectMapping

    public func map(project: Project) throws -> (Project, [SideEffectDescriptor]) {
        let schemeNames = Set(project.schemes.map(\.name))
        let schemes = project.schemes

        let autogeneratedSchemes = project.targets.compactMap { (target: Target) -> Scheme? in
            let scheme = self.createDefaultScheme(target: target,
                                                  project: project,
                                                  codeCoverage: enableCodeCoverage,
                                                  buildConfiguration: project.defaultDebugBuildConfigurationName)
            // The user has already defined a scheme with that name.
            if schemeNames.contains(scheme.name) { return nil }
            return scheme
        }

        return (project.with(schemes: schemes + autogeneratedSchemes), [])
    }

    // MARK: - Private

    private func createDefaultScheme(target: Target, project: Project, codeCoverage: Bool, buildConfiguration: String) -> Scheme {
        let targetReference = TargetReference(projectPath: project.path, name: target.name)

        let buildTargets = buildableTargets(targetReference: targetReference, target: target, project: project)
        let testTargets = testableTargets(targetReference: targetReference, target: target, project: project)
        let executable = runnableExecutable(targetReference: targetReference, target: target, project: project)

        let codeCoverageTargets = codeCoverage ? [targetReference] : []
        let arguments = defaultArguments(for: target)

        return Scheme(name: target.name,
                      shared: true,
                      buildAction: BuildAction(targets: buildTargets),
                      testAction: TestAction(targets: testTargets,
                                             arguments: nil,
                                             configurationName: buildConfiguration,
                                             coverage: enableCodeCoverage,
                                             codeCoverageTargets: codeCoverageTargets,
                                             preActions: [],
                                             postActions: [],
                                             diagnosticsOptions: [.mainThreadChecker]),
                      runAction: RunAction(configurationName: buildConfiguration,
                                           executable: executable,
                                           filePath: nil,
                                           arguments: arguments,
                                           diagnosticsOptions: [.mainThreadChecker]))
    }

    private func buildableTargets(targetReference: TargetReference,
                                  target: Target,
                                  project: Project) -> [TargetReference]
    {
        switch target.product {
        case .appExtension, .messagesExtension:
            let hostAppTargets = hostAppTargetReferences(for: target, project: project)
            return [targetReference] + hostAppTargets
        default:
            return [targetReference]
        }
    }

    private func testableTargets(targetReference: TargetReference,
                                 target: Target,
                                 project: Project) -> [TestableTarget]
    {
        if target.product.testsBundle {
            return [TestableTarget(target: targetReference)]
        } else {
            // The test targets that are dependant on the given target.
            return project.targets
                .filter { $0.product.testsBundle && $0.dependencies.contains(.target(name: target.name)) }
                .sorted(by: { $0.name < $1.name })
                .map { TargetReference(projectPath: project.path, name: $0.name) }
                .map { TestableTarget(target: $0) }
        }
    }

    private func runnableExecutable(targetReference: TargetReference,
                                    target: Target,
                                    project: Project) -> TargetReference?
    {
        switch target.product {
        case .appExtension, .messagesExtension:
            return hostAppTargetReferences(for: target, project: project).first
        case .watch2Extension:
            return hostWatchAppTargetReferences(for: target, project: project).first
        default:
            return targetReference
        }
    }

    private func hostAppTargetReferences(for target: Target,
                                         project: Project) -> [TargetReference]
    {
        project.targets
            .filter { $0.product.canHostTests() && $0.dependencies.contains(.target(name: target.name)) }
            .sorted(by: { $0.name < $1.name })
            .map { TargetReference(projectPath: project.path, name: $0.name) }
    }

    private func hostWatchAppTargetReferences(for target: Target,
                                              project: Project) -> [TargetReference]
    {
        project.targets
            .filter { $0.product == .watch2App && $0.dependencies.contains(.target(name: target.name)) }
            .sorted(by: { $0.name < $1.name })
            .map { TargetReference(projectPath: project.path, name: $0.name) }
    }

    private func defaultArguments(for target: Target) -> Arguments? {
        if target.environment.isEmpty, target.launchArguments.isEmpty {
            return nil
        }
        return Arguments(environment: target.environment, launchArguments: target.launchArguments)
    }
}
