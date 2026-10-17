#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ImageLibrary

/// Resolves named images for MetalRack renderers and SwiftUI image views.
public struct ImageLibrary {
    public typealias Loader = (String) -> UIImage?

    public static var shared = ImageLibrary()

    private let loader: Loader

    public init(loader: @escaping Loader = { name in
        UIImage(named: name)
    }) {
        self.loader = loader
    }

    public func image(named name: String) -> UIImage? {
        loader(name)
    }

    public func image(named names: [String]) -> UIImage? {
        for name in names where !name.isEmpty {
            if let image = image(named: name) {
                return image
            }
        }
        return nil
    }

    public func swiftUIImage(named names: [String]) -> Image? {
        image(named: names).map(Image.init(uiImage:))
    }
}

#endif
