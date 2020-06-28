import Foundation
import RxSwift
import TSCBasic
import TuistCore
import TuistSupport

// TODO: Later, add a warmup function to check if it's correctly authenticated ONCE
final class CacheRemoteStorage: CacheStoring {
    // MARK: - Attributes

    private let cloudClient: CloudClienting
    private let fileClient: FileClienting
    private let fileArchiverFactory: FileArchiverManufacturing
    private var fileArchiverMap: [AbsolutePath: FileArchiving] = [:]

    // MARK: - Init

    init(cloudClient: CloudClienting,
         fileArchiverFactory: FileArchiverManufacturing = FileArchiverFactory(),
         fileClient: FileClienting = FileClient()) {
        self.cloudClient = cloudClient
        self.fileArchiverFactory = fileArchiverFactory
        self.fileClient = fileClient
    }

    // MARK: - CacheStoring

    func exists(hash: String, config: Config) -> Single<Bool> {
        do {
            let successRange = 200 ..< 300
            let resource = try CloudHEADResponse.existsResource(hash: hash, config: config)
            return cloudClient.request(resource)
                .flatMap { _, response in
                    .just(successRange.contains(response.statusCode))
                }
                .catchError { error in
                    if case let HTTPRequestDispatcherError.serverSideError(_, response) = error, response.statusCode == 404 {
                        return .just(false)
                    } else {
                        throw error
                    }
                }
        } catch {
            return Single.error(error)
        }
    }

    func fetch(hash: String, config: Config) -> Single<AbsolutePath> {
        do {
            let resource = try CloudCacheResponse.fetchResource(hash: hash, config: config)
            return cloudClient
                .request(resource)
                .map { $0.object.data.url }
                .flatMap { (url: URL) in self.fileClient.download(url: url) }
                .flatMap { (filePath: AbsolutePath) in
                    do {
                        let archiveContentPath = try self.zipFlow(downloadedArchive: filePath, hash: hash)
                        return Single.just(archiveContentPath)
                    } catch {
                        return Single.error(error)
                    }
                }
        } catch {
            return Single.error(error)
        }
    }

    func store(hash: String, config: Config, xcframeworkPath: AbsolutePath) -> Completable {
        do {
            let archiver = fileArchiver(for: xcframeworkPath)
            let destinationZipPath = try archiver.zip()
            let resource = try CloudCacheResponse.storeResource(
                hash: hash,
                config: config,
                contentMD5: try FileHandler.shared.base64MD5(path: destinationZipPath)
            )

            return cloudClient
                .request(resource)
                .map { (responseTuple) -> URL in responseTuple.object.data.url }
                .flatMapCompletable { (url: URL) in
                    let deleteCompletable = self.deleteZipArchiveCompletable(archiver: archiver)
                    return self.fileClient.upload(file: destinationZipPath, hash: hash, to: url).asCompletable()
                        .andThen(deleteCompletable)
                        .catchError { deleteCompletable.concat(.error($0)) }
                }
        } catch {
            return Completable.error(error)
        }
    }

    // MARK: - Private

    private func zipFlow(downloadedArchive: AbsolutePath, hash: String) throws -> AbsolutePath {
        let zipPath = try FileHandler.shared.changeExtension(path: downloadedArchive, to: "zip")
        let archiver = fileArchiver(for: zipPath)
        let archiveDestination = Environment.shared.xcframeworksCacheDirectory.appending(component: hash)
        try archiver.unzip(to: archiveDestination)
        let folderContent = try FileHandler.shared.contentsOfDirectory(archiveDestination)
        let archiveContentPath = folderContent.filter { FileHandler.shared.isFolder($0) }.first ?? archiveDestination
        print("content: \(archiveContentPath)")
        return archiveContentPath
    }

    private func fileArchiver(for path: AbsolutePath) -> FileArchiving {
        let fileArchiver = fileArchiverMap[path] ?? fileArchiverFactory.makeFileArchiver(for: path)
        fileArchiverMap[path] = fileArchiver
        return fileArchiver
    }

    private func deleteZipArchiveCompletable(archiver: FileArchiving) -> Completable {
        Completable.create(subscribe: { observer in
            do {
                try archiver.delete()
                observer(.completed)
            } catch {
                observer(.error(error))
            }
            return Disposables.create {}
        })
    }

    // MARK: - Deinit

    deinit {
        do {
            try fileArchiverMap.values.forEach { fileArchiver in try fileArchiver.delete() }
        } catch {}
    }
}
