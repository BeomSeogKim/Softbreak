# Writing app ideation

## Status

Discovery and the first two feedback passes are complete. This file is the source of truth for product direction and benchmark evidence.

## Product definition

- **First writer:** A macOS user who writes local Markdown documents, especially essays, notes, specifications, and reports that may need to become PDFs.
- **Writing moment:** Starting or continuing a document when the writer wants the interface, Markdown syntax, preview switching, and print setup to recede.
- **Problem:** Existing tools split their strengths. Inline rendering can make a document pleasant to read but complicate source editing; source-first tools protect Markdown but often separate writing, reading, and final print layout.
- **Smallest complete flow:** Create or open a `.md` file, write with the current paragraph held in view, apply common Markdown structures from the keyboard, read the rendered document without a visual reset, and directly export an A4 PDF.
- **Validation:** Compare the same writing and export task with Typora and iA Writer. Standard formatting shortcuts must remain available, Write and Read must share their base visual tokens, a round-trip fixture must stay byte-for-byte safe, and PDF generation must not become a permanent screen mode.

## Product principle

The interface should feel like paper while writing and like a dependable instrument when inspecting or exporting. Writing is the default state; tools appear only when asked for.

The continuity promise is precise: Write and Read share the selected background, body font, measure, and vertical rhythm. Read applies Markdown presentation; Write retains visible source. PDF reuses the Read renderer and selected theme, and is generated only during export.

## Benchmark observations

### Typora

- Markdown becomes readable in place immediately; syntax markers largely disappear outside the active block.
- `Command-0` through `Command-6` are paragraph and H1-H6. Bold, italic, link, code, quote, lists, and heading promotion are all menu commands with keyboard shortcuts.
- Focus mode dims every block except the current one, and typewriter mode keeps the active line near the vertical center.
- Source Mode is separate from the default live preview, while PDF is an Export command rather than a document mode.
- The default writing column and interface are quiet, although the file sidebar competes with the canvas until hidden.
- Printing uses the standard macOS A4 print preview and includes a top-heading page-break option.
- Six built-in CSS themes are exposed from a direct Theme menu; Typora can also remember separate choices for system Light and Dark appearances.
- The strongest lesson is continuity between writing and reading. The main risk to avoid is making hidden syntax or inline rich editing the source of cursor, selection, undo, and Korean IME errors.

### iA Writer

- The editor keeps Markdown markers visible in a sparse monospaced writing surface.
- `Command-1` through `Command-6` are H1-H6, `Command-R` toggles Preview, and `Shift-Command-E` opens Export.
- Sentence and paragraph focus, plus a separate typewriter option, are explicit and easy to discover.
- Editor and Preview remain distinct states but retain the same application shell and selectable document template.
- Application Light/Dark appearance is separate from Preview and PDF templates.
- Export offers Markdown, HTML, PDF, Word, and project archive formats; PDF is a direct export choice.
- Smart Lists continue list markers on Return, while Format exposes headings, lists, quote, inline styles, links, code blocks, tables, footnotes, content blocks, and page breaks.
- An untitled test document was automatically placed in the configured iCloud library as a `.txt` file. The new app should instead make local file location and `.md` identity explicit.
- The strongest lesson for this product is that dependable PDF styling can remain an export concern instead of becoming a permanent document mode.

## Decisions

1. **Platform:** macOS only for the first product.
2. **Storage:** Plain local `.md` and `.markdown` files. No library or account requirement.
3. **Typing surface:** AppKit `NSTextView` and TextKit 2. Keep the Markdown source as the only document truth.
4. **Editing model:** Source-first. Syntax may be de-emphasized, but delimiters are not hidden in the first slice.
5. **Focus:** Paragraph focus and typewriter scrolling ship in the first slice; sentence focus can follow after Korean boundary behavior is tested.
6. **Rendering:** One safe Markdown-to-HTML renderer and one selected theme for Read and print export. Write consumes the same background, body font, measure, and rhythm tokens.
7. **PDF:** PDF is export-only. Ask for the destination first, generate a fresh A4 artifact from the current Markdown, relative-resource base, and selected theme, validate it, and write it atomically.
8. **Keyboard contract:** `Command-0...6`, `Command-B`, `Command-I`, and `Command-K` follow the common Typora/iA Writer contract. Code, strikethrough, quote, bulleted/numbered/task lists, and heading level changes also live in Format so macOS App Shortcuts can remap them.
9. **Non-goals:** Accounts, cloud sync, collaboration, AI writing, plugins, knowledge graphs, publishing, mobile platforms, and a theme marketplace.
10. **Themes:** Theme is a global presentation preference, not document metadata. Paper, Snow, and Sage are the light set; Ink, Midnight, and Pine are the dark set. All six preserve typography and layout, meet normal-text contrast, update every open window, and survive relaunch.

## Feature audit and adoption order

### Adopted in the current pass

- Paragraph and H1-H6 shortcuts, heading promotion and demotion
- Bold, italic, strikethrough, inline code, link, fenced code, quote, bulleted list, numbered list, and task list commands
- A discoverable Format menu backed by the current text view's responder chain and one-step undo
- `Command-R` for Read and direct `Shift-Command-E` PDF export
- Shared screen tokens across Write and Read
- A direct Theme menu with three light and three dark palettes, global persistence, and matching Write, Read, and PDF output

### Next candidates

- Smart List continuation and empty-item exit on Return
- Selection-aware bracket completion for links, images, and footnotes
- Optional sentence focus after Korean boundary testing
- Word count that fades out while typing
- Outline and quick-open surfaces for longer document sets
- Explicit page breaks and footnotes for PDF-oriented documents
- An optional System appearance mode that remembers separate light and dark choices

### Deliberately later

- Typora-style live preview inside the editable TextKit surface; cursor, selection, undo, and Korean IME behavior need a dedicated prototype
- User templates, tables, math, content blocks, wikilinks, and document libraries
- iA Writer Syntax Highlight and Style Check; the official language support does not include Korean

Official references checked on 2026-09-01:

- Typora: [Shortcut Keys](https://support.typora.io/Shortcut-Keys/), [Quick Start](https://support.typora.io/Quick-Start/), [Focus and Typewriter Mode](https://support.typora.io/Focus-and-Typewriter-Mode/), [About Themes](https://support.typora.io/About-Themes/), [Export](https://support.typora.io/Export/)
- iA Writer: [Keyboard Shortcuts](https://ia.net/writer/support/basics/shortcuts?tab=keyboard-shortcuts-mac), [Settings](https://ia.net/writer/support/basics/settings?tab=settings-mac), [Focus Mode](https://ia.net/writer/support/editor/focus-mode), [Modify Preview](https://ia.net/writer/support/preview/modify-preview/modify-preview-mac), [Templates](https://ia.net/writer/support/preview/templates?tab=templates-mac), [Export, Share, Print](https://ia.net/writer/support/preview/export-share-print?tab=export-mac), [Smart Automation](https://ia.net/writer/support/editor/smart-automation/smart-automation-mac)

## Open questions after the first slice

1. Should source-first Write remain the default, or should a future inline preview selectively replace stable blocks after its TextKit/IME prototype passes?
2. Which Korean body font and line length best sustain long writing sessions across screen and A4 output?
3. Should folders and outlines appear as transient command surfaces or remain outside the initial product?
4. Which unsupported Markdown extensions are important enough to add without making the editor feel like an IDE?
5. Should PDF page numbers, headers, and explicit page breaks enter the next slice?
