import Foundation

public extension String {
    public func chomp(separator: String? = nil) -> String {
        func scrub(_ separator: String) -> String {
            var e = endIndex
            while String(self[startIndex..<e]).hasSuffix(separator), e > startIndex {
                e = index(before: e)
            }
            return String(self[startIndex..<e])
        }

        if let separator {
            return scrub(separator)
        } else if hasSuffix("\r\n") {
            return scrub("\r\n")
        } else if hasSuffix("\n") {
            return scrub("\n")
        } else {
            return self
        }
    }
}