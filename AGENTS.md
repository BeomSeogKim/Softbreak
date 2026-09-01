# Project instructions

## Context

This is a macOS-first Markdown editor experiment. Its primary value is helping a writer stay inside the act of writing while keeping standard local Markdown files and producing a faithful PDF.

## Working rules

- Keep changes minimal and appropriate to the current vertical slice.
- Preserve plain Markdown as the source of truth; presentation state must never rewrite a document's Markdown.
- Keep the typing path native and synchronous work on each keystroke small. Parsing, preview rendering, and PDF work must not block input.
- Reuse one HTML/CSS document renderer for reading and PDF export. Generate PDF only after the user chooses Export PDF; do not add a PDF screen mode.
- Keep common Markdown commands discoverable in the Format menu. `Command-0` through `Command-6`, `Command-B`, `Command-I`, and `Command-K` belong to document formatting, not view navigation.
- Record product questions, concepts, evidence, and decisions in `notes/IDEATION.md`.
- Write project documentation, code, configuration, and comments in English. Communicate with the owner in Korean unless asked otherwise.
- Manage future local secrets with sealbox using the project name `writing-app`; do not create a committed `.env` file.
- Preserve user changes and avoid unrelated cleanup.

## Current success criterion

The current slice is complete when a macOS user can create or open a local `.md` file, format Markdown with standard keyboard commands, move between visually continuous Write and Read views, save without Markdown loss, and directly export a valid A4 PDF.
