import Basic
import Foundation
import XCTest

import TuistGenerator
@testable import ProjectDescription
@testable import TuistCoreTesting
@testable import TuistKit

class GeneratorModelLoaderTest: XCTestCase {
    typealias WorkspaceManifest = ProjectDescription.Workspace
    typealias ProjectManifest = ProjectDescription.Project
    typealias TargetManifest = ProjectDescription.Target
    typealias SettingsManifest = ProjectDescription.Settings
    typealias ConfigurationManifest = ProjectDescription.Configuration
    typealias HeadersManifest = ProjectDescription.Headers
    typealias SchemeManifest = ProjectDescription.Scheme
    typealias BuildActionManifest = ProjectDescription.BuildAction
    typealias TestActionManifest = ProjectDescription.TestAction
    typealias RunActionManifest = ProjectDescription.RunAction
    typealias ArgumentsManifest = ProjectDescription.Arguments

    private var manifestTargetGenerator: MockManifestTargetGenerator!
    private var manifestLinter: MockManifestLinter!

    private var fileHandler: MockFileHandler!
    private var path: AbsolutePath {
        return fileHandler.currentPath
    }

    private var printer: MockPrinter!

    override func setUp() {
        do {
            printer = MockPrinter()
            fileHandler = try MockFileHandler()
            manifestTargetGenerator = MockManifestTargetGenerator()
            manifestLinter = MockManifestLinter()
        } catch {
            XCTFail("setup failed: \(error.localizedDescription)")
        }
    }

    override func tearDown() {
        fileHandler = nil
    }

    func test_loadProject() throws {
        // Given

        let manifests = [
            path: ProjectManifest.test(name: "SomeProject"),
        ]

        let manifestLoader = createManifestLoader(with: manifests)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadProject(at: path)

        // Then
        XCTAssertEqual(model.name, "SomeProject")
        XCTAssertEqual(model.targets.map { $0.name }, ["SomeProject-Manifest"])
    }

    func test_loadProject_withTargets() throws {
        // Given
        let targetA = TargetManifest.test(name: "A")
        let targetB = TargetManifest.test(name: "B")
        let manifests = [
            path: ProjectManifest.test(name: "Project",
                                       targets: [
                                           targetA,
                                           targetB,
                                       ]),
        ]

        let manifestLoader = createManifestLoader(with: manifests)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadProject(at: path)

        // Then
        XCTAssertEqual(model.targets.count, 3)
        assert(target: model.targets[0], matches: targetA, at: path)
        assert(target: model.targets[1], matches: targetB, at: path)
        XCTAssertEqual(model.targets[2].name, "Project-Manifest")
    }

    func test_loadProject_withManifestTargetOptionDisabled() throws {
        // Given
        try fileHandler.createFiles([
            "TuistConfig.swift",
        ])
        let projects = [
            path: ProjectManifest.test(name: "Project",
                                       targets: [
                                           .test(name: "A"),
                                           .test(name: "B"),
                                       ]),
        ]

        let configs = [
            path: TuistConfig.test(generationOptions: []),
        ]

        let manifestLoader = createManifestLoader(with: projects, configs: configs)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadProject(at: path)

        // Then
        XCTAssertEqual(model.targets.map(\.name), [
            "A",
            "B",
        ])
    }

    func test_loadProject_withAdditionalFiles() throws {
        // Given
        let files = try fileHandler.createFiles([
            "Documentation/README.md",
            "Documentation/guide.md",
        ])

        let manifests = [
            path: ProjectManifest.test(name: "SomeProject",
                                       additionalFiles: [
                                           "Documentation/**/*.md",
                                       ]),
        ]

        let manifestLoader = createManifestLoader(with: manifests)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadProject(at: path)

        // Then
        XCTAssertEqual(model.additionalFiles, files.map { .file(path: $0) })
    }

    func test_loadProject_withFolderReferences() throws {
        // Given
        let files = try fileHandler.createFolders([
            "Stubs",
        ])

        let manifests = [
            path: ProjectManifest.test(name: "SomeProject",
                                       additionalFiles: [
                                           .folderReference(path: "Stubs"),
                                       ]),
        ]

        let manifestLoader = createManifestLoader(with: manifests)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadProject(at: path)

        // Then
        XCTAssertEqual(model.additionalFiles, files.map { .folderReference(path: $0) })
    }

    func test_loadProject_withCustomName() throws {
        // Given
        try fileHandler.createFiles([
            "TuistConfig.swift",
        ])

        let manifests = [
            path: ProjectManifest.test(name: "SomeProject",
                                       additionalFiles: [
                                           .folderReference(path: "Stubs"),
                                       ]),
        ]
        let configs = [
            path: ProjectDescription.TuistConfig.test(generationOptions: [.xcodeProjectName("one \(.projectName) two")]),
        ]
        let manifestLoader = createManifestLoader(with: manifests, configs: configs)
        let subject = GeneratorModelLoader(fileHandler: fileHandler,
                                           manifestLoader: manifestLoader,
                                           manifestLinter: manifestLinter,
                                           manifestTargetGenerator: manifestTargetGenerator)

        // When
        let model = try subject.loadProject(at: path)

        // Then
        XCTAssertEqual(model.fileName, "one SomeProject two")
    }

    func test_loadProject_withCustomNameDuplicates() throws {
        // Given
        try fileHandler.createFiles([
            "TuistConfig.swift",
        ])

        let manifests = [
            path: ProjectManifest.test(name: "SomeProject",
                                       additionalFiles: [
                                           .folderReference(path: "Stubs"),
                                       ]),
        ]
        let configs = [
            path: ProjectDescription.TuistConfig.test(generationOptions: [.xcodeProjectName("one \(.projectName) two"),
                                                                          .xcodeProjectName("two \(.projectName) three")]),
        ]
        let manifestLoader = createManifestLoader(with: manifests, configs: configs)
        let subject = GeneratorModelLoader(fileHandler: fileHandler,
                                           manifestLoader: manifestLoader,
                                           manifestLinter: manifestLinter,
                                           manifestTargetGenerator: manifestTargetGenerator)

        // When
        let model = try subject.loadProject(at: path)

        // Then
        XCTAssertEqual(model.fileName, "one SomeProject two")
    }

    func test_loadWorkspace() throws {
        // Given
        let manifests = [
            path: WorkspaceManifest.test(name: "SomeWorkspace"),
        ]

        let manifestLoader = createManifestLoader(with: manifests)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadWorkspace(at: path)

        // Then
        XCTAssertEqual(model.name, "SomeWorkspace")
        XCTAssertEqual(model.projects, [])
    }

    func test_loadWorkspace_withProjects() throws {
        // Given
        let path = fileHandler.currentPath
        let projects = try fileHandler.createFolders([
            "A",
            "B",
        ])

        let manifests = [
            path: WorkspaceManifest.test(name: "SomeWorkspace", projects: ["A", "B"]),
        ]

        let manifestLoader = createManifestLoader(with: manifests, projects: projects)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadWorkspace(at: path)

        // Then
        XCTAssertEqual(model.name, "SomeWorkspace")
        XCTAssertEqual(model.projects, projects)
    }

    func test_loadWorkspace_withAdditionalFiles() throws {
        let path = fileHandler.currentPath
        let files = try fileHandler.createFiles([
            "Documentation/README.md",
            "Documentation/setup/README.md",
            "Playground.playground",
        ])

        let manifests = [
            path: WorkspaceManifest.test(name: "SomeWorkspace",
                                         projects: [],
                                         additionalFiles: [
                                             "Documentation/**/*.md",
                                             "*.playground",
                                         ]),
        ]

        let manifestLoader = createManifestLoader(with: manifests)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadWorkspace(at: path)

        // Then
        XCTAssertEqual(model.name, "SomeWorkspace")
        XCTAssertEqual(model.additionalFiles, files.map { .file(path: $0) })
    }

    func test_loadWorkspace_withFolderReferences() throws {
        let path = fileHandler.currentPath
        try fileHandler.createFiles([
            "Documentation/README.md",
            "Documentation/setup/README.md",
        ])

        let manifests = [
            path: WorkspaceManifest.test(name: "SomeWorkspace",
                                         projects: [],
                                         additionalFiles: [
                                             .folderReference(path: "Documentation"),
                                         ]),
        ]

        let manifestLoader = createManifestLoader(with: manifests)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadWorkspace(at: path)

        // Then
        XCTAssertEqual(model.name, "SomeWorkspace")
        XCTAssertEqual(model.additionalFiles, [
            .folderReference(path: path.appending(RelativePath("Documentation"))),
        ])
    }

    func test_loadWorkspace_withInvalidProjectsPaths() throws {
        // Given
        let path = fileHandler.currentPath

        let manifests = [
            path: WorkspaceManifest.test(name: "SomeWorkspace", projects: ["A", "B"]),
        ]

        let manifestLoader = createManifestLoader(with: manifests)
        let subject = createGeneratorModelLoader(with: manifestLoader)

        // When
        let model = try subject.loadWorkspace(at: path)

        // Then
        XCTAssertEqual(printer.printWarningArgs, [
            "No projects found at: A",
            "No projects found at: B",
        ])
        XCTAssertEqual(model.projects, [])
    }

    func test_settings() throws {
        // Given
        let debug = ConfigurationManifest(settings: ["Debug": "Debug"], xcconfig: "debug.xcconfig")
        let release = ConfigurationManifest(settings: ["Release": "Release"], xcconfig: "release.xcconfig")
        let manifest = SettingsManifest(base: ["base": "base"], debug: debug, release: release)

        // When
        let model = TuistGenerator.Settings.from(manifest: manifest, path: path)

        // Then
        assert(settings: model, matches: manifest, at: path)
    }

    func test_dependency_when_cocoapods() throws {
        // Given
        let dependency = TargetDependency.cocoapods(path: "./path/to/project")

        // When
        let got = TuistGenerator.Dependency.from(manifest: dependency)

        // Then
        guard case let .cocoapods(path) = got else {
            XCTFail("Dependency should be cocoapods")
            return
        }
        XCTAssertEqual(path, RelativePath("./path/to/project"))
    }

    func test_headers() throws {
        // Given
        try fileHandler.createFiles([
            "Sources/public/A1.h",
            "Sources/public/A1.m",
            "Sources/public/A2.h",
            "Sources/public/A2.m",

            "Sources/private/B1.h",
            "Sources/private/B1.m",
            "Sources/private/B2.h",
            "Sources/private/B2.m",

            "Sources/project/C1.h",
            "Sources/project/C1.m",
            "Sources/project/C2.h",
            "Sources/project/C2.m",
        ])

        let manifest = HeadersManifest(public: "Sources/public/**",
                                       private: "Sources/private/**",
                                       project: "Sources/project/**")

        // When
        let model = TuistGenerator.Headers.from(manifest: manifest, path: path, fileHandler: fileHandler)

        // Then
        XCTAssertEqual(model.public, [
            "Sources/public/A1.h",
            "Sources/public/A2.h",
        ].map { fileHandler.currentPath.appending(RelativePath($0)) })

        XCTAssertEqual(model.private, [
            "Sources/private/B1.h",
            "Sources/private/B2.h",
        ].map { fileHandler.currentPath.appending(RelativePath($0)) })

        XCTAssertEqual(model.project, [
            "Sources/project/C1.h",
            "Sources/project/C2.h",
        ].map { fileHandler.currentPath.appending(RelativePath($0)) })
    }

    func test_headersArray() throws {
        // Given
        try fileHandler.createFiles([
            "Sources/public/A/A1.h",
            "Sources/public/A/A1.m",
            "Sources/public/B/B1.h",
            "Sources/public/B/B1.m",

            "Sources/private/C/C1.h",
            "Sources/private/C/C1.m",
            "Sources/private/D/D1.h",
            "Sources/private/D/D1.m",

            "Sources/project/E/E1.h",
            "Sources/project/E/E1.m",
            "Sources/project/F/F1.h",
            "Sources/project/F/F1.m",
        ])

        let manifest = HeadersManifest(public: ["Sources/public/A/*.h", "Sources/public/B/*.h"],
                                       private: ["Sources/private/C/*.h", "Sources/private/D/*.h"],
                                       project: ["Sources/project/E/*.h", "Sources/project/F/*.h"])

        // When
        let model = TuistGenerator.Headers.from(manifest: manifest, path: path, fileHandler: fileHandler)

        // Then
        XCTAssertEqual(model.public, [
            "Sources/public/A/A1.h",
            "Sources/public/B/B1.h",
        ].map { fileHandler.currentPath.appending(RelativePath($0)) })

        XCTAssertEqual(model.private, [
            "Sources/private/C/C1.h",
            "Sources/private/D/D1.h",
        ].map { fileHandler.currentPath.appending(RelativePath($0)) })

        XCTAssertEqual(model.project, [
            "Sources/project/E/E1.h",
            "Sources/project/F/F1.h",
        ].map { fileHandler.currentPath.appending(RelativePath($0)) })
    }

    func test_headersStringAndArrayMix() throws {
        // Given
        try fileHandler.createFiles([
            "Sources/public/A/A1.h",
            "Sources/public/A/A1.m",

            "Sources/project/C/C1.h",
            "Sources/project/C/C1.m",
            "Sources/project/D/D1.h",
            "Sources/project/D/D1.m",
        ])

        let manifest = HeadersManifest(public: "Sources/public/A/*.h",
                                       project: ["Sources/project/C/*.h", "Sources/project/D/*.h"])

        // When
        let model = TuistGenerator.Headers.from(manifest: manifest, path: path, fileHandler: fileHandler)

        // Then
        XCTAssertEqual(model.public, [
            "Sources/public/A/A1.h",
        ].map { fileHandler.currentPath.appending(RelativePath($0)) })

        XCTAssertEqual(model.project, [
            "Sources/project/C/C1.h",
            "Sources/project/D/D1.h",
        ].map { fileHandler.currentPath.appending(RelativePath($0)) })
    }

    func test_coreDataModel() throws {
        // Given
        try fileHandler.touch(path.appending(component: "model.xcdatamodeld"))
        let manifest = ProjectDescription.CoreDataModel("model.xcdatamodeld",
                                                        currentVersion: "1")

        // When
        let model = try TuistGenerator.CoreDataModel.from(manifest: manifest, path: path, fileHandler: fileHandler)

        // Then
        XCTAssertTrue(coreDataModel(model, matches: manifest, at: path))
    }

    func test_targetActions() throws {
        // Given
        let manifest = ProjectDescription.TargetAction.test(name: "MyScript",
                                                            tool: "my_tool",
                                                            path: "my/path",
                                                            order: .pre,
                                                            arguments: ["arg1", "arg2"])
        // When
        let model = TuistGenerator.TargetAction.from(manifest: manifest, path: path)

        // Then
        XCTAssertEqual(model.name, "MyScript")
        XCTAssertEqual(model.tool, "my_tool")
        XCTAssertEqual(model.path, path.appending(RelativePath("my/path")))
        XCTAssertEqual(model.order, .pre)
        XCTAssertEqual(model.arguments, ["arg1", "arg2"])
    }

    func test_scheme_withoutActions() throws {
        // Given
        let manifest = SchemeManifest.test(name: "Scheme",
                                           shared: false)
        // When
        let model = TuistGenerator.Scheme.from(manifest: manifest)

        // Then
        assert(scheme: model, matches: manifest)
    }

    func test_scheme_withActions() throws {
        // Given
        let arguments = ArgumentsManifest.test(environment: ["FOO": "BAR", "FIZ": "BUZZ"],
                                               launch: ["--help": true,
                                                        "subcommand": false])
        let buildAction = BuildActionManifest.test(targets: ["A", "B"])
        let runActions = RunActionManifest.test(config: .release,
                                                executable: "A",
                                                arguments: arguments)
        let testAction = TestActionManifest.test(targets: ["B"],
                                                 arguments: arguments,
                                                 config: .debug,
                                                 coverage: true)
        let manifest = SchemeManifest.test(name: "Scheme",
                                           shared: true,
                                           buildAction: buildAction,
                                           testAction: testAction,
                                           runAction: runActions)
        // When
        let model = TuistGenerator.Scheme.from(manifest: manifest)

        // Then
        assert(scheme: model, matches: manifest)
    }

    func test_platform_watchOSNotSupported() {
        XCTAssertThrowsError(
            try TuistGenerator.Platform.from(manifest: .watchOS)
        ) { error in
            XCTAssertEqual(error as? GeneratorModelLoaderError, GeneratorModelLoaderError.featureNotYetSupported("watchOS platform"))
        }
    }

    func test_generatorModelLoaderError_type() {
        XCTAssertEqual(GeneratorModelLoaderError.featureNotYetSupported("").type, .abort)
        XCTAssertEqual(GeneratorModelLoaderError.missingFile("/missing/path").type, .abort)
    }

    func test_generatorModelLoaderError_description() {
        XCTAssertEqual(GeneratorModelLoaderError.featureNotYetSupported("abc").description, "abc is not yet supported")
        XCTAssertEqual(GeneratorModelLoaderError.missingFile("/missing/path").description, "Couldn't find file at path '/missing/path'")
    }

    func test_fileElement_warning_withDirectoryPathsAsFiles() throws {
        // Given
        let path = fileHandler.currentPath
        try fileHandler.createFiles([
            "Documentation/README.md",
            "Documentation/USAGE.md",
        ])

        let manifest = ProjectDescription.FileElement.glob(pattern: "Documentation")

        // When
        let model = TuistGenerator.FileElement.from(manifest: manifest,
                                                    path: path,
                                                    fileHandler: fileHandler,
                                                    printer: printer,
                                                    includeFiles: { !self.fileHandler.isFolder($0) })

        // Then
        XCTAssertEqual(printer.printWarningArgs, [
            "'Documentation' is a directory, try using: 'Documentation/**' to list its files",
        ])
        XCTAssertEqual(model, [])
    }

    func test_fileElement_warning_withMisingPaths() throws {
        // Given
        let path = fileHandler.currentPath
        let manifest = ProjectDescription.FileElement.glob(pattern: "Documentation/**")

        // When
        let model = TuistGenerator.FileElement.from(manifest: manifest,
                                                    path: path,
                                                    fileHandler: fileHandler,
                                                    printer: printer)

        // Then
        XCTAssertEqual(printer.printWarningArgs, [
            "No files found at: Documentation/**",
        ])
        XCTAssertEqual(model, [])
    }

    func test_fileElement_warning_withInvalidFolderReference() throws {
        // Given
        let path = fileHandler.currentPath
        try fileHandler.createFiles([
            "README.md",
        ])

        let manifest = ProjectDescription.FileElement.folderReference(path: "README.md")

        // When
        let model = TuistGenerator.FileElement.from(manifest: manifest,
                                                    path: path,
                                                    fileHandler: fileHandler,
                                                    printer: printer)

        // Then
        XCTAssertEqual(printer.printWarningArgs, [
            "README.md is not a directory - folder reference paths need to point to directories",
        ])
        XCTAssertEqual(model, [])
    }

    func test_fileElement_warning_withMissingFolderReference() throws {
        // Given
        let path = fileHandler.currentPath
        let manifest = ProjectDescription.FileElement.folderReference(path: "Documentation")

        // When
        let model = TuistGenerator.FileElement.from(manifest: manifest,
                                                    path: path,
                                                    fileHandler: fileHandler,
                                                    printer: printer)

        // Then
        XCTAssertEqual(printer.printWarningArgs, [
            "Documentation does not exist",
        ])
        XCTAssertEqual(model, [])
    }

    // MARK: - Helpers

    func createGeneratorModelLoader(with manifestLoader: GraphManifestLoading) -> GeneratorModelLoader {
        return GeneratorModelLoader(fileHandler: fileHandler,
                                    manifestLoader: manifestLoader,
                                    manifestLinter: manifestLinter,
                                    manifestTargetGenerator: manifestTargetGenerator,
                                    printer: printer)
    }

    func createManifestLoader(with projects: [AbsolutePath: ProjectDescription.Project],
                              configs: [AbsolutePath: ProjectDescription.TuistConfig] = [:]) -> GraphManifestLoading {
        let manifestLoader = MockGraphManifestLoader()
        manifestLoader.loadProjectStub = { path in
            guard let manifest = projects[path] else {
                throw GraphManifestLoaderError.manifestNotFound(path)
            }
            return manifest
        }
        manifestLoader.loadTuistConfigStub = { path in
            guard let manifest = configs[path] else {
                throw GraphManifestLoaderError.manifestNotFound(path)
            }
            return manifest
        }
        manifestLoader.manifestsAtStub = { path in
            var manifests = Set<Manifest>()
            if projects[path] != nil {
                manifests.insert(.project)
            }

            if configs[path] != nil {
                manifests.insert(.tuistConfig)
            }
            return manifests
        }
        return manifestLoader
    }

    func createManifestLoader(with workspaces: [AbsolutePath: ProjectDescription.Workspace],
                              projects: [AbsolutePath] = []) -> GraphManifestLoading {
        let manifestLoader = MockGraphManifestLoader()
        manifestLoader.loadWorkspaceStub = { path in
            guard let manifest = workspaces[path] else {
                throw GraphManifestLoaderError.manifestNotFound(path)
            }
            return manifest
        }
        manifestLoader.manifestsAtStub = { path in
            projects.contains(path) ? Set([.project]) : Set([])
        }
        return manifestLoader
    }

    func assert(target: TuistGenerator.Target,
                matches manifest: ProjectDescription.Target,
                at path: AbsolutePath,
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertEqual(target.name, manifest.name, file: file, line: line)
        XCTAssertEqual(target.bundleId, manifest.bundleId, file: file, line: line)
        XCTAssertTrue(target.platform == manifest.platform, file: file, line: line)
        XCTAssertTrue(target.product == manifest.product, file: file, line: line)
        XCTAssertEqual(target.infoPlist?.path, path.appending(RelativePath(manifest.infoPlist.path!)), file: file, line: line)
        XCTAssertEqual(target.entitlements, manifest.entitlements.map { path.appending(RelativePath($0)) }, file: file, line: line)
        XCTAssertEqual(target.environment, manifest.environment, file: file, line: line)
        assert(coreDataModels: target.coreDataModels, matches: manifest.coreDataModels, at: path, file: file, line: line)
        optionalAssert(target.settings, manifest.settings, file: file, line: line) {
            assert(settings: $0, matches: $1, at: path, file: file, line: line)
        }
    }

    func assert(settings: TuistGenerator.Settings,
                matches manifest: ProjectDescription.Settings,
                at path: AbsolutePath,
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertEqual(settings.base, manifest.base, file: file, line: line)

        let sortedConfigurations = settings.configurations.sorted { (l, r) -> Bool in l.key.name < r.key.name }
        let sortedManifsetConfigurations = manifest.configurations.sorted(by: { $0.name < $1.name })
        for (configuration, manifestConfiguration) in zip(sortedConfigurations, sortedManifsetConfigurations) {
            assert(configuration: configuration, matches: manifestConfiguration, at: path, file: file, line: line)
        }
    }

    func assert(configuration: (TuistGenerator.BuildConfiguration, TuistGenerator.Configuration?),
                matches manifest: ProjectDescription.CustomConfiguration,
                at path: AbsolutePath,
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertTrue(configuration.0 == manifest, file: file, line: line)
        XCTAssertEqual(configuration.1?.settings, manifest.configuration?.settings, file: file, line: line)
        XCTAssertEqual(configuration.1?.xcconfig, manifest.configuration?.xcconfig.map { path.appending(RelativePath($0)) }, file: file, line: line)
    }

    func assert(coreDataModels: [TuistGenerator.CoreDataModel],
                matches manifests: [ProjectDescription.CoreDataModel],
                at path: AbsolutePath,
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertEqual(coreDataModels.count, manifests.count, file: file, line: line)
        XCTAssertTrue(coreDataModels.elementsEqual(manifests, by: { coreDataModel($0, matches: $1, at: path) }),
                      file: file,
                      line: line)
    }

    func coreDataModel(_ coreDataModel: TuistGenerator.CoreDataModel,
                       matches manifest: ProjectDescription.CoreDataModel,
                       at path: AbsolutePath) -> Bool {
        return coreDataModel.path == path.appending(RelativePath(manifest.path))
            && coreDataModel.currentVersion == manifest.currentVersion
    }

    func assert(scheme: TuistGenerator.Scheme,
                matches manifest: ProjectDescription.Scheme,
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertEqual(scheme.name, manifest.name, file: file, line: line)
        XCTAssertEqual(scheme.shared, manifest.shared, file: file, line: line)
        optionalAssert(scheme.buildAction, manifest.buildAction) {
            assert(buildAction: $0, matches: $1, file: file, line: line)
        }

        optionalAssert(scheme.testAction, manifest.testAction) {
            assert(testAction: $0, matches: $1, file: file, line: line)
        }

        optionalAssert(scheme.runAction, manifest.runAction) {
            assert(runAction: $0, matches: $1, file: file, line: line)
        }
    }

    func assert(buildAction: TuistGenerator.BuildAction,
                matches manifest: ProjectDescription.BuildAction,
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertEqual(buildAction.targets, manifest.targets, file: file, line: line)
    }

    func assert(testAction: TuistGenerator.TestAction,
                matches manifest: ProjectDescription.TestAction,
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertEqual(testAction.targets, manifest.targets, file: file, line: line)
        XCTAssertTrue(testAction.configurationName == manifest.configurationName, file: file, line: line)
        XCTAssertEqual(testAction.coverage, manifest.coverage, file: file, line: line)
        optionalAssert(testAction.arguments, manifest.arguments) {
            assert(arguments: $0, matches: $1, file: file, line: line)
        }
    }

    func assert(runAction: TuistGenerator.RunAction,
                matches manifest: ProjectDescription.RunAction,
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertEqual(runAction.executable, manifest.executable, file: file, line: line)
        XCTAssertTrue(runAction.configurationName == manifest.configurationName, file: file, line: line)
        optionalAssert(runAction.arguments, manifest.arguments) {
            assert(arguments: $0, matches: $1, file: file, line: line)
        }
    }

    func assert(arguments: TuistGenerator.Arguments,
                matches manifest: ProjectDescription.Arguments,
                file: StaticString = #file,
                line: UInt = #line) {
        XCTAssertEqual(arguments.environment, manifest.environment, file: file, line: line)
        XCTAssertEqual(arguments.launch, manifest.launch, file: file, line: line)
    }

    func optionalAssert<A, B>(_ optionalA: A?,
                              _ optionalB: B?,
                              file: StaticString = #file,
                              line: UInt = #line,
                              compare: (A, B) -> Void) {
        switch (optionalA, optionalB) {
        case let (a?, b?):
            compare(a, b)
        case (nil, nil):
            break
        default:
            XCTFail("mismatch of optionals", file: file, line: line)
        }
    }
}

private func == (_ lhs: TuistGenerator.Platform,
                 _ rhs: ProjectDescription.Platform) -> Bool {
    let map: [TuistGenerator.Platform: ProjectDescription.Platform] = [
        .iOS: .iOS,
        .macOS: .macOS,
        .tvOS: .tvOS,
    ]
    return map[lhs] == rhs
}

private func == (_ lhs: TuistGenerator.Product,
                 _ rhs: ProjectDescription.Product) -> Bool {
    let map: [TuistGenerator.Product: ProjectDescription.Product] = [
        .app: .app,
        .framework: .framework,
        .staticFramework: .staticFramework,
        .unitTests: .unitTests,
        .uiTests: .uiTests,
        .staticLibrary: .staticLibrary,
        .dynamicLibrary: .dynamicLibrary,
    ]
    return map[lhs] == rhs
}

private func == (_ lhs: BuildConfiguration,
                 _ rhs: CustomConfiguration) -> Bool {
    let map: [BuildConfiguration.Variant: CustomConfiguration.Variant] = [
        .debug: .debug,
        .release: .release,
    ]
    return map[lhs.variant] == rhs.variant && lhs.name == rhs.name
}

extension AbsolutePath: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
