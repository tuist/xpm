import Foundation
import TSCBasic

internal class HashingFilesFilter {
    /// an array of filters, which should return if a path should be included in hashing calculations or not.
    private let filters: [(AbsolutePath) -> Bool]

    internal init() {
        filters = [
            { $0.basename.uppercased() != ".DS_STORE" },
        ]
    }

    internal func callAsFunction(_ path: AbsolutePath) -> Bool {
        !filters.contains(where: { $0(path) == false })
    }
}
