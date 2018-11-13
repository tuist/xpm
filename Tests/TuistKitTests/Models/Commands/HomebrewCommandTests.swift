import Basic
import Foundation
import TuistCore
import XCTest

@testable import TuistCoreTesting
@testable import TuistKit

final class HomebrewCommandTests: XCTestCase {
    var system: MockSystem!
    var fileHandler: MockFileHandler!
    var printer: MockPrinter!

    override func setUp() {
        system = MockSystem()
        fileHandler = try! MockFileHandler()
        printer = MockPrinter()
        super.setUp()
    }

    func test_isMet_when_homebrew_is_missing() throws {
        let subject = HomebrewCommand(packages: [])
        system.whichStub = { tool in
            if tool == "brew" {
                throw NSError.test()
            } else {
                return ""
            }
        }
        let got = try subject.isMet(system: system, projectPath: fileHandler.currentPath)
        XCTAssertFalse(got)
    }

    func test_isMet_when_a_package_is_missing() throws {
        let subject = HomebrewCommand(packages: ["swiftlint"])
        system.whichStub = { tool in
            if tool == "swiftlint" {
                throw NSError.test()
            } else {
                return ""
            }
        }
        let got = try subject.isMet(system: system, projectPath: fileHandler.currentPath)
        XCTAssertFalse(got)
    }

    func test_isMet() throws {
        let subject = HomebrewCommand(packages: ["swiftlint"])
        system.whichStub = { _ in "" }
        let got = try subject.isMet(system: system, projectPath: fileHandler.currentPath)
        XCTAssertTrue(got)
    }

    func test_meet() throws {
        let subject = HomebrewCommand(packages: ["swiftlint"])

        system.whichStub = { _ in nil }
        system.stub(args: ["/usr/bin/ruby",
                           "-e",
                           "\"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)\""],
                    stderror: nil,
                    stdout: nil,
                    exitstatus: 0)
        system.stub(args: ["/usr/local/bin/brew", "install", "swiftlint"],
                    stderror: nil,
                    stdout: nil,
                    exitstatus: 0)

        try subject.meet(system: system, printer: printer, projectPath: fileHandler.currentPath)

        XCTAssertTrue(printer.printArgs.contains("Installing Homebrew"))
        XCTAssertTrue(printer.printArgs.contains("Installing Homebrew package: swiftlint"))
    }
}
