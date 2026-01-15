import Foundation
import XCTest
import PluginSupport

open class GekoPluginTestCase: XCTestCase {
    fileprivate var temporaryDirectory: TemporaryDirectory!

    override open func tearDown() {
        temporaryDirectory = nil
        TestingLogHandler.reset()
        super.tearDown()
    }

    public func temporaryPath() throws -> AbsolutePath {
        if temporaryDirectory == nil {
            temporaryDirectory = try TemporaryDirectory(removeTreeOnDeinit: true)
        }
        return temporaryDirectory.path
    }
}
