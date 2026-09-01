import AppKit

@MainActor
enum DocumentTheme {
    static let maximumLineWidth: CGFloat = 700
    static let minimumHorizontalInset: CGFloat = 32
    static let minimumVerticalInset: CGFloat = 64
    static let typewriterPosition: CGFloat = 0.42
    static let bodyFontSize: CGFloat = 18
    static let bodyLineHeight: CGFloat = 31.5

    static let bodyFont = NSFont.systemFont(ofSize: bodyFontSize, weight: .regular)

    static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = bodyLineHeight
        style.maximumLineHeight = bodyLineHeight
        style.paragraphSpacing = 0
        style.lineBreakMode = .byWordWrapping
        return style
    }()

    static let backgroundColor = dynamicColor(
        light: (0xFB, 0xFA, 0xF7),
        dark: (0x1D, 0x1C, 0x1A)
    )
    static let textColor = dynamicColor(
        light: (0x26, 0x25, 0x22),
        dark: (0xE8, 0xE5, 0xDF)
    )

    static var screenCSS: String {
        """
        :root {
          color-scheme: light dark;
          font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", sans-serif;
          font-size: \(bodyFontSize)px;
          line-height: 1.75;
          --document-block-gap: 1.75rem;
          color: #262522;
          background: #fbfaf7;
        }

        body {
          max-width: calc(\(maximumLineWidth)px + \(minimumHorizontalInset * 2)px);
          margin: 0 auto;
          padding: max(\(minimumVerticalInset)px, \(typewriterPosition * 100)vh)
            \(minimumHorizontalInset)px
            max(8rem, \(typewriterPosition * 100)vh);
          overflow-wrap: break-word;
        }

        @media (prefers-color-scheme: dark) {
          :root {
            color: #e8e5df;
            background: #1d1c1a;
          }
        }
        """
    }

    private static func dynamicColor(
        light: (Int, Int, Int),
        dark: (Int, Int, Int)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let components = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? dark
                : light
            return NSColor(
                srgbRed: CGFloat(components.0) / 255,
                green: CGFloat(components.1) / 255,
                blue: CGFloat(components.2) / 255,
                alpha: 1
            )
        }
    }
}
