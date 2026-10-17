#if canImport(UIKit)
import SwiftUI
public struct SpriteImage<Placeholder: View>: View {
    let candidateNames: [String]
    var contentMode: ContentMode = .fit
    @ViewBuilder let placeholder: () -> Placeholder

    public init(candidateNames: [String], contentMode: ContentMode = .fit, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.candidateNames = candidateNames; self.contentMode = contentMode; self.placeholder = placeholder
    }
    public var body: some View {
        Group {
            if let image = ImageLibrary.shared.swiftUIImage(named: candidateNames) {
                image
                    .resizable()
            } else {
                placeholder()
            }
        }
        .aspectRatio(contentMode: contentMode)
    }
}


#endif
