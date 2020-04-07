import Basic
import Foundation
import SPMUtility
import TuistSupport

/// Protocol that represents an entity that knows how to get the environment status
/// for a given project and configure it.
public protocol SetupLoading {
    /// It runs meet on each command if it is not met.
    ///
    /// - Parameter path: Path to the project.
    /// - Throws: An error if any of the commands exit unsuccessfully.
    func meet(at path: AbsolutePath) throws
}

public class SetupLoader: SetupLoading {
    /// Linter for up commands.
    private let upLinter: UpLinting

    /// Manifset loader instance to load the setup.
    private let manifestLoader: ManifestLoading

    /// Versions fetcher.
    private let versionsFetcher: VersionsFetching

    /// Default constructor.
    public convenience init() {
        let upLinter = UpLinter()
        let manifestLoader = ManifestLoader()
        self.init(upLinter: upLinter, manifestLoader: manifestLoader, versionsFetcher: VersionsFetcher())
    }

    /// Initializes the command with its arguments.
    ///
    /// - Parameters:
    ///   - upLinter: Linter for up commands.
    ///   - manifestLoader: Manifset loader instance to load the setup.
    ///   - versionsFetcher: Utility to fetch the versions of the system components that Tuist interacts with.
    init(upLinter: UpLinting,
         manifestLoader: ManifestLoading,
         versionsFetcher: VersionsFetching) {
        self.upLinter = upLinter
        self.manifestLoader = manifestLoader
        self.versionsFetcher = versionsFetcher
    }

    /// It runs meet on each command if it is not met.
    ///
    /// - Parameter path: Path to the project.
    /// - Throws: An error if any of the commands exit unsuccessfully
    ///           or if there isn't a `Setup.swift` file within the project path.
    public func meet(at path: AbsolutePath) throws {
        let versions = try versionsFetcher.fetch()
        let setup = try manifestLoader.loadSetup(at: path, versions: versions)
        try setup.map { command in upLinter.lint(up: command) }
            .flatMap { $0 }
            .printAndThrowIfNeeded()
        try setup.forEach { command in
            if try !command.isMet(projectPath: path) {
                logger.notice("Configuring \(command.name)", metadata: .subsection)
                try command.meet(projectPath: path)
            }
        }
    }
}
