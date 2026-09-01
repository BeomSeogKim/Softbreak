import AppKit

enum DocumentTheme: String, CaseIterable, Sendable {
    enum Family: String, Sendable {
        case light
        case dark
    }

    struct Palette: Equatable, Sendable {
        let background: String
        let text: String
        let mutedText: String
        let surface: String
        let border: String
        let quoteBorder: String
        let link: String
    }

    case paper
    case snow
    case sage
    case ink
    case midnight
    case pine

    static let defaultTheme = DocumentTheme.paper
    static let maximumLineWidth: CGFloat = 700
    static let minimumHorizontalInset: CGFloat = 32
    static let minimumVerticalInset: CGFloat = 64
    static let typewriterPosition: CGFloat = 0.42
    static let bodyFontSize: CGFloat = 18
    static let bodyLineHeight: CGFloat = 31.5

    @MainActor
    static let bodyFont = NSFont.systemFont(ofSize: bodyFontSize, weight: .regular)

    @MainActor
    static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = bodyLineHeight
        style.maximumLineHeight = bodyLineHeight
        style.paragraphSpacing = 0
        style.lineBreakMode = .byWordWrapping
        return style
    }()

    static var lightThemes: [DocumentTheme] {
        allCases.filter { $0.family == .light }
    }

    static var darkThemes: [DocumentTheme] {
        allCases.filter { $0.family == .dark }
    }

    var displayName: String {
        switch self {
        case .paper: "Paper"
        case .snow: "Snow"
        case .sage: "Sage"
        case .ink: "Ink"
        case .midnight: "Midnight"
        case .pine: "Pine"
        }
    }

    var family: Family {
        switch self {
        case .paper, .snow, .sage:
            .light
        case .ink, .midnight, .pine:
            .dark
        }
    }

    var palette: Palette {
        switch self {
        case .paper:
            Palette(
                background: "#FBFAF7",
                text: "#262522",
                mutedText: "#69655E",
                surface: "#EEEAE2",
                border: "#D7D2C9",
                quoteBorder: "#C8C3B8",
                link: "#315F86"
            )
        case .snow:
            Palette(
                background: "#FCFCFD",
                text: "#202124",
                mutedText: "#62666C",
                surface: "#F1F3F5",
                border: "#D9DDE2",
                quoteBorder: "#C2C8D0",
                link: "#285F9E"
            )
        case .sage:
            Palette(
                background: "#F5F8F3",
                text: "#253027",
                mutedText: "#59675D",
                surface: "#E8EFE6",
                border: "#CCD8CC",
                quoteBorder: "#AABCAA",
                link: "#3E6F56"
            )
        case .ink:
            Palette(
                background: "#1D1C1A",
                text: "#E8E5DF",
                mutedText: "#B8B2A8",
                surface: "#2A2824",
                border: "#47433D",
                quoteBorder: "#565149",
                link: "#8BB8DC"
            )
        case .midnight:
            Palette(
                background: "#171B24",
                text: "#E7EAF0",
                mutedText: "#AEB6C5",
                surface: "#222936",
                border: "#394355",
                quoteBorder: "#53627A",
                link: "#8CBEEE"
            )
        case .pine:
            Palette(
                background: "#18201D",
                text: "#E4EAE6",
                mutedText: "#ACB9B1",
                surface: "#23302A",
                border: "#3B4A42",
                quoteBorder: "#52695D",
                link: "#8BC8AA"
            )
        }
    }

    @MainActor
    var backgroundColor: NSColor {
        Self.color(from: palette.background)
    }

    @MainActor
    var textColor: NSColor {
        Self.color(from: palette.text)
    }

    @MainActor
    var appearance: NSAppearance? {
        NSAppearance(named: family == .dark ? .darkAqua : .aqua)
    }

    var screenCSS: String {
        let palette = palette
        return """
        :root {
          color-scheme: \(family.rawValue);
          font-family: -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", sans-serif;
          font-size: \(Self.bodyFontSize)px;
          line-height: 1.75;
          --document-block-gap: 1.75rem;
          --document-background: \(palette.background);
          --document-text: \(palette.text);
          --document-muted-text: \(palette.mutedText);
          --document-surface: \(palette.surface);
          --document-border: \(palette.border);
          --document-quote-border: \(palette.quoteBorder);
          --document-link: \(palette.link);
          color: var(--document-text);
          background: var(--document-background);
        }

        html {
          min-height: 100%;
          background: var(--document-background);
        }

        body {
          max-width: calc(\(Self.maximumLineWidth)px + \(Self.minimumHorizontalInset * 2)px);
          margin: 0 auto;
          padding: \(Self.minimumVerticalInset)px
            \(Self.minimumHorizontalInset)px
            max(8rem, \(Self.minimumVerticalInset)px);
          overflow-wrap: break-word;
          background: var(--document-background);
        }

        @media print {
          :root {
            font-size: 10.5pt;
            --document-block-gap: 1.35rem;
          }

          html,
          body {
            min-height: 100%;
            background: var(--document-background);
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
          }
        }

        @page {
          background: \(palette.background);
        }
        """
    }

    @MainActor
    private static func color(from hex: String) -> NSColor {
        let digits = hex.dropFirst()
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            preconditionFailure("Document theme colors must use six-digit hexadecimal values.")
        }

        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
