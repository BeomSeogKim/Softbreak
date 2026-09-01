# Softbreak

A macOS-first Markdown editor for staying with the writing and taking the same typography cleanly to PDF.

> Markdown, without breaking your flow.

## Product promise

Open a normal Markdown file, write without interface noise, read it in the same visual environment, and export a dependable PDF only when needed.

The editor keeps Markdown as plain text. It does not require an account, library, proprietary document format, or cloud service.

## First vertical slice

- Native macOS document open, create, save, autosave, undo, and redo
- A quiet, top-starting writing column with optional paragraph focus and typewriter scrolling
- Standard Markdown formatting commands in the menu and responder chain
- Three light themes and three dark themes shared by Write and Read
- A rendered Read view using the selected colors and the same body font, measure, and vertical rhythm as Write
- Direct A4 PDF export in the selected theme with no separate PDF screen

The first slice deliberately excludes accounts, sync, collaboration, AI writing, plugins, document databases, publishing, mobile platforms, and theme marketplaces.

## Technology direction

The typing surface is AppKit `NSTextView` with TextKit 2. Pure UTF-16-aware transforms implement Markdown formatting without introducing rich-text state. Markdown is parsed away from the typing path and rendered to safe HTML. WebKit owns both the Read view and the hidden print layout; PDFKit validates the generated PDF before it is written.

The working product and benchmark decisions are recorded in [`notes/IDEATION.md`](notes/IDEATION.md).

## Status

Discovery and the first interaction review are complete. The native slice is implemented and available as an Apple Silicon beta for macOS 14 or later.

## Install

Install the current beta from the project Homebrew tap:

```sh
brew install --cask beomseogkim/tap/softbreak
```

The beta is ad-hoc signed because the project does not yet have an Apple Developer ID certificate. macOS therefore requires one explicit approval on first launch: try to open Softbreak, then go to **System Settings → Privacy & Security** and choose **Open Anyway**. Only do this after confirming that the download came from this repository's release.

You can also download the DMG directly from [GitHub Releases](https://github.com/BeomSeogKim/Softbreak/releases/latest), open it, and drag `Softbreak.app` to `Applications`.

## Build and run

Requirements: macOS 14 or later and Xcode with the Swift 6 toolchain.

```sh
swift test
./scripts/make-app.sh release
open "build/Softbreak.app"
```

The packaging script creates a standard `.app` bundle, copies the shared document stylesheet into `Contents/Resources`, and verifies its signature. To create a versioned Apple Silicon DMG and SHA-256 checksum, run:

```sh
./scripts/make-dmg.sh 0.1.0-beta.1
```

Developer ID signing and notarization remain future distribution work. Set `CODE_SIGN_IDENTITY` when running the packaging scripts after a Developer ID certificate becomes available.

## Writing flow

- `Command-0`: paragraph; `Command-1` through `Command-6`: headings
- `Command-B`, `Command-I`, `Command-K`: bold, italic, and link
- `Command-J`, `Shift-Command-J`, `Option-Command-U`: inline code, code block, and strikethrough
- `Option-Command-Q`, `Shift-Command-8`, `Shift-Command-7`, `Option-Command-L`: quote, bulleted list, numbered list, and task list
- `Return`: continue indentation, quotes, bullets, ordered numbers, and tasks; use Return on an empty item to exit it
- `Shift-Return`: insert a plain line break without continuing a Markdown prefix
- `Command-R`: toggle the visually matched Write and Read views
- `Shift-Command-E`: choose a destination, generate the current document, and export an A4 PDF
- `View → Paragraph Focus`: dim everything outside the active paragraph; on by default
- `View → Typewriter Scrolling`: keep the caret at 42% of the viewport; off by default

The two writing behaviors are independent, apply to Write only, and persist across launches. Standard macOS New, Open, Save, Save As, undo, redo, find, full screen, and recent-document commands are available from the menu bar.

## Themes

The top-level `Theme` menu offers Paper, Snow, and Sage for light writing, plus Ink, Midnight, and Pine for dark writing. The choice applies immediately to every open document, persists across launches, and changes presentation only: Markdown, selection, and undo history remain untouched.

## License

Softbreak is available under the [MIT License](LICENSE).
