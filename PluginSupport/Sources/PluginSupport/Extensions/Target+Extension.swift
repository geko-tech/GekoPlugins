import ProjectDescription

extension Target {
    /// Returns the product name including the extension.
    public var productNameWithExtension: String {
        switch product {
        case .staticLibrary, .dynamicLibrary:
            return "lib\(productName).\(product.xcodeValue.fileExtension!)"
        case .commandLineTool:
            return productName
        case _:
            if let fileExtension = product.xcodeValue.fileExtension {
                return "\(productName).\(fileExtension)"
            } else {
                return productName
            }
        }
    }
}
