# Writing app

A macOS-first Markdown editor for staying with the writing and taking the same typography cleanly to PDF.

## Product promise

Open a normal Markdown file, write without interface noise, read it in the same visual environment, and export a dependable PDF only when needed.

The editor keeps Markdown as plain text. It does not require an account, library, proprietary document format, or cloud service.

## First vertical slice

- Native macOS document open, create, save, autosave, undo, and redo
- A centered writing column with paragraph focus and typewriter scrolling
- Standard Markdown formatting commands in the menu and responder chain
- A rendered Read view using the same colors, body font, measure, and vertical rhythm as Write
- Direct A4 PDF export with no separate PDF screen

The first slice deliberately excludes accounts, sync, collaboration, AI writing, plugins, document databases, publishing, mobile platforms, and theme marketplaces.

## Technology direction

The typing surface is AppKit `NSTextView` with TextKit 2. Pure UTF-16-aware transforms implement Markdown formatting without introducing rich-text state. Markdown is parsed away from the typing path and rendered to safe HTML. WebKit owns both the Read view and the hidden print layout; PDFKit validates the generated PDF before it is written.

The working product and benchmark decisions are recorded in [`notes/IDEATION.md`](notes/IDEATION.md).

## Status

Discovery and the first interaction review are complete. The native slice is implemented and available as a local, ad-hoc-signed macOS app.

## Build and run

Requirements: macOS 14 or later and Xcode with the Swift 6 toolchain.

```sh
swift test
./scripts/make-app.sh release
open "build/Writing App.app"
```

The packaging script creates a standard `.app` bundle, copies the shared document stylesheet into `Contents/Resources`, and verifies its ad-hoc signature. Distribution signing, notarization, sandboxing, and an installer are intentionally outside this first local slice.

## Writing flow

- `Command-0`: paragraph; `Command-1` through `Command-6`: headings
- `Command-B`, `Command-I`, `Command-K`: bold, italic, and link
- `Command-J`, `Shift-Command-J`, `Option-Command-U`: inline code, code block, and strikethrough
- `Option-Command-Q`, `Shift-Command-8`, `Shift-Command-7`, `Option-Command-L`: quote, bulleted list, numbered list, and task list
- `Command-R`: toggle the visually matched Write and Read views
- `Shift-Command-E`: choose a destination, generate the current document, and export an A4 PDF

Standard macOS New, Open, Save, Save As, undo, redo, find, full screen, and recent-document commands are available from the menu bar.
