import Foundation
import TSCBasic
import TuistSupport

enum BundleServiceError: FatalError, Equatable {
    case missingVersionFile(AbsolutePath)

    var type: ErrorType {
        switch self {
        case .missingVersionFile:
            return .abort
        }
    }

    var description: String {
        switch self {
        case let .missingVersionFile(path):
            return "Couldn't find a .tuist-version file in the directory \(path.pathString)"
        }
    }

    static func == (lhs: BundleServiceError, rhs: BundleServiceError) -> Bool {
        switch (lhs, rhs) {
        case let (.missingVersionFile(lhsPath), .missingVersionFile(rhsPath)):
            return lhsPath == rhsPath
        }
    }
}

final class BundleService {
    private let versionsController: VersionsControlling
    private let installer: Installing

    init(versionsController: VersionsControlling = VersionsController(),
         installer: Installing = Installer()) {
        self.versionsController = versionsController
        self.installer = installer
    }

    func run() throws {
        let versionFilePath = FileHandler.shared.currentPath.appending(component: Constants.versionFileName)
        let binFolderPath = FileHandler.shared.currentPath.appending(component: Constants.binFolderName)

        if !FileHandler.shared.exists(versionFilePath) {
            throw BundleServiceError.missingVersionFile(FileHandler.shared.currentPath)
        }

        let version = try String(contentsOf: versionFilePath.url)
        let cleanVersion = version.filter { !$0.isWhitespace }
        logger.notice("Bundling the version \(cleanVersion) in the directory \(binFolderPath.pathString)", metadata: .section)

        let versionPath = versionsController.path(version: cleanVersion)

        // Installing
        if !FileHandler.shared.exists(versionPath) {
            logger.notice("Version \(cleanVersion) not available locally. Installing...")
            try installer.install(version: cleanVersion, force: false)
        }

        // Copying
        if FileHandler.shared.exists(binFolderPath) {
            try FileHandler.shared.delete(binFolderPath)
        }
        try FileHandler.shared.copy(from: versionPath, to: binFolderPath)

        logger.notice("tuist bundled successfully at \(binFolderPath.pathString)", metadata: .success)
    }
}
