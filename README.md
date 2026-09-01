# Writing app

A macOS-first Markdown editor for staying with the writing and taking the same typography cleanly to PDF.

## Product promise

Open a normal Markdown file, write without interface noise, and export the PDF you already inspected.

The editor keeps Markdown as plain text. It does not require an account, library, proprietary document format, or cloud service.

## First vertical slice

- Native macOS document open, create, save, autosave, undo, and redo
- A centered writing column with paragraph focus and typewriter scrolling
- Standard Markdown source editing with restrained syntax styling
- A read preview rendered from the document's Markdown
- A real A4 PDF preview and export of that exact artifact

The first slice deliberately excludes accounts, sync, collaboration, AI writing, plugins, document databases, publishing, mobile platforms, and theme marketplaces.

## Technology direction

The typing surface is AppKit `NSTextView` with TextKit 2. Markdown is parsed away from the typing path and rendered to safe HTML. WebKit owns both the read view and print layout; PDFKit displays the generated PDF before export.

The working product and benchmark decisions are recorded in [`notes/IDEATION.md`](notes/IDEATION.md).

## Status

Discovery is complete. The first native vertical slice is implemented and available as a local, ad-hoc-signed macOS app.

## Build and run

Requirements: macOS 14 or later and Xcode with the Swift 6 toolchain.

```sh
swift test
./scripts/make-app.sh release
open "build/Writing App.app"
```

The packaging script creates a standard `.app` bundle, copies the shared document stylesheet into `Contents/Resources`, and verifies its ad-hoc signature. Distribution signing, notarization, sandboxing, and an installer are intentionally outside this first local slice.

## Writing flow

- `Command-1`: source-first Write view with paragraph focus and typewriter scrolling
- `Command-2`: rendered Read view
- `Command-3`: actual A4 PDF preview
- `Shift-Command-E`: export the exact PDF artifact shown in preview

Standard macOS New, Open, Save, Save As, undo, redo, find, full screen, and recent-document commands are available from the menu bar.
