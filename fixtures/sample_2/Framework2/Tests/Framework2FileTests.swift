@testable import Framework2
import XCTest

class Framework2Tests: XCTestCase {

    func testHello() {
        let sut = Framework2File()

        XCTAssertEqual("Framework2File.hello()", sut.hello())
    }
}
