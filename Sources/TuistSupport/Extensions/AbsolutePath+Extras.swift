import Darwin
import Foundation
import TSCBasic

let systemGlob = Darwin.glob

public enum GlobError: FatalError, Equatable {
    case nonExistentDirectory(InvalidGlob)

    public var type: ErrorType { .abort }

    public var description: String {
        switch self {
        case let .nonExistentDirectory(invalidGlob):
            return String(describing: invalidGlob)
        }
    }
}

extension AbsolutePath {
    /// Returns the current path.
    public static var current: AbsolutePath {
        AbsolutePath(FileManager.default.currentDirectoryPath)
    }

    /// Returns the URL that references the absolute path.
    public var url: URL {
        URL(fileURLWithPath: pathString)
    }

    /// Returns the list of paths that match the given glob pattern.
    ///
    /// - Parameter pattern: Relative glob pattern used to match the paths.
    /// - Returns: List of paths that match the given pattern.
    public func glob(_ pattern: String) -> [AbsolutePath] {
        Glob(pattern: appending(RelativePath(pattern)).pathString).paths.map { AbsolutePath($0) }
    }

    /// Returns the list of paths that match the given glob pattern, if the directory exists.
    ///
    /// - Parameter pattern: Relative glob pattern used to match the paths.
    /// - Throws: an error if the directory where the first glob pattern is declared doesn't exist
    /// - Returns: List of paths that match the given pattern.
    public func throwingGlob(_ pattern: String) throws -> [AbsolutePath] {
        let globPath = appending(RelativePath(pattern)).pathString

        if globPath.isGlobComponent {
            let pathUpToLastNonGlob = AbsolutePath(globPath).upToLastNonGlob

            if !pathUpToLastNonGlob.isFolder {
                let invalidGlob = InvalidGlob(pattern: globPath,
                                              nonExistentPath: pathUpToLastNonGlob)
                throw GlobError.nonExistentDirectory(invalidGlob)
            }
        }

        return glob(pattern)
    }

    /// Returns true if the path points to a directory
    public var isFolder: Bool {
        var isDirectory = ObjCBool(true)
        let exists = FileManager.default.fileExists(atPath: pathString, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    /// Returns the path with the last component removed. For example, given the path
    /// /test/path/to/file it returns /test/path/to
    ///
    /// If the path is one-level deep from the root directory it returns the root directory.
    ///
    /// - Returns: Path with the last component removed.
    public func removingLastComponent() -> AbsolutePath {
        AbsolutePath("/\(components.dropLast().joined(separator: "/"))")
    }

    /// Returns the common ancestor path with another path
    ///
    /// e.g.
    ///     /path/to/a
    ///     /path/another/b
    ///
    ///     common ancestor: /path
    ///
    /// - Parameter path: The other path to find a common path with
    /// - Returns: An absolute path to the common ancestor
    public func commonAncestor(with path: AbsolutePath) -> AbsolutePath {
        var ancestorPath = AbsolutePath("/")
        for component in components.dropFirst() {
            let nextPath = ancestorPath.appending(component: component)
            if path.contains(nextPath) {
                ancestorPath = nextPath
            } else {
                break
            }
        }
        return ancestorPath
    }

    /// Returns the hash of the file the path points to.
    public func sha256() -> Data? {
        try? SHA256Digest.file(at: url)
    }

    /// Returns target and configuration name from a file name
    ///
    /// Expects the file to be named "TargetName.ConfigurationName.extension"
    ///
    /// - Returns: Tuple consisting of targetName and configurationName
    func extractTargetAndConfigurationName() -> (targetName: String, configurationName: String)? {
        let components = self.basenameWithoutExt.components(separatedBy: ".")
        guard components.count == 2 else { return nil }
        return (String(components[0]), String(components[1]))
    }

}

extension AbsolutePath: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = AbsolutePath(value)
    }
}

extension String {
    var isGlobComponent: Bool {
        let globCharacters = CharacterSet(charactersIn: "*{}")
        return rangeOfCharacter(from: globCharacters) != nil
    }
}

extension AbsolutePath {
    var upToLastNonGlob: AbsolutePath {
        guard let index = components.firstIndex(where: { $0.isGlobComponent }) else {
            return self
        }

        return AbsolutePath(components[0 ..< index].joined(separator: "/"))
    }
}
