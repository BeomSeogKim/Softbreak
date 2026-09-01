# Writing app ideation

## Status

Discovery is complete for the first vertical slice. This file is the source of truth for product direction and benchmark evidence.

## Product definition

- **First writer:** A macOS user who writes local Markdown documents, especially essays, notes, specifications, and reports that may need to become PDFs.
- **Writing moment:** Starting or continuing a document when the writer wants the interface, Markdown syntax, preview switching, and print setup to recede.
- **Problem:** Existing tools split their strengths. Inline rendering can make a document pleasant to read but complicate source editing; source-first tools protect Markdown but often separate writing, reading, and final print layout.
- **Smallest complete flow:** Create or open a `.md` file, write with the current paragraph held in view, save the unchanged Markdown source, inspect the rendered document, inspect the actual paged PDF, and export that same PDF.
- **Validation:** Compare the same writing and export task with Typora and iA Writer. The new flow should require no more than one command to enter focus, no more than one command to reach the real PDF preview, preserve a round-trip fixture byte-for-byte, and keep typing responsive in a 1 MB document.

## Product principle

The interface should feel like paper while writing and like a dependable instrument when inspecting or exporting. Writing is the default state; tools appear only when asked for.

The fidelity promise is precise: the continuous editor cannot be pixel-identical to paged paper, but the PDF preview and exported PDF must be the same artifact.

## Benchmark observations

### Typora

- Markdown becomes readable in place immediately; syntax markers largely disappear outside the active block.
- Focus mode dims every block except the current one, and typewriter mode keeps the active line near the vertical center.
- The default writing column and interface are quiet, although the file sidebar competes with the canvas until hidden.
- Printing uses the standard macOS A4 print preview and includes a top-heading page-break option.
- The strongest lesson is continuity between writing and reading. The main risk to avoid is making hidden syntax or inline rich editing the source of cursor, selection, undo, and Korean IME errors.

### iA Writer

- The editor keeps Markdown markers visible in a sparse monospaced writing surface.
- Sentence and paragraph focus, plus a separate typewriter option, are explicit and easy to discover.
- Web preview and true paged PDF preview are both available inside the same window, with selectable output templates.
- Export offers Markdown, HTML, PDF, Word, and project archive formats; PDF is a direct export choice.
- An untitled test document was automatically placed in the configured iCloud library as a `.txt` file. The new app should instead make local file location and `.md` identity explicit.
- The strongest lesson is that a real PDF page preview is a first-class view, not a print-dialog afterthought.

## Decisions

1. **Platform:** macOS only for the first product.
2. **Storage:** Plain local `.md` and `.markdown` files. No library or account requirement.
3. **Typing surface:** AppKit `NSTextView` and TextKit 2. Keep the Markdown source as the only document truth.
4. **Editing model:** Source-first. Syntax may be de-emphasized, but delimiters are not hidden in the first slice.
5. **Focus:** Paragraph focus and typewriter scrolling ship in the first slice; sentence focus can follow after Korean boundary behavior is tested.
6. **Rendering:** One safe Markdown-to-HTML renderer and one bundled CSS document theme for both read and print views.
7. **PDF:** Generate a real paged PDF, display it with PDFKit, and export the same temporary file without rendering a second time.
8. **Non-goals:** Accounts, cloud sync, collaboration, AI writing, plugins, knowledge graphs, publishing, mobile platforms, and a theme marketplace.

## Open questions after the first slice

1. Should restrained inline syntax styling remain source-first, or should a future inline preview selectively replace stable blocks?
2. Which Korean body font and line length best sustain long writing sessions across screen and A4 output?
3. Should folders and outlines appear as transient command surfaces or remain outside the initial product?
4. Which unsupported Markdown extensions are important enough to add without making the editor feel like an IDE?
5. Should PDF page numbers, headers, and explicit page breaks enter the second slice?
