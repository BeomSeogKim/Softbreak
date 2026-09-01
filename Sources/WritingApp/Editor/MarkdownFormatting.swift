import Foundation

struct MarkdownEdit: Equatable {
    let replacementRange: NSRange
    let replacement: String
    let selectionAfter: NSRange
}

enum MarkdownFormatting {
    enum BlockStyle {
        case quote
        case unorderedList
        case orderedList
        case taskList
    }

    static func heading(
        level: Int,
        source: String,
        selection: NSRange
    ) -> MarkdownEdit? {
        guard (0...6).contains(level) else { return nil }

        return transformLinePrefixes(source: source, selection: selection) { lines in
            lines.map { line in
                let parsed = parseHeading(in: line.body)
                let marker = level == 0 ? "" : String(repeating: "#", count: level) + " "
                return PrefixChange(
                    oldPrefixLength: parsed.prefixLength,
                    newPrefix: parsed.indentation + marker,
                    content: parsed.content
                )
            }
        }
    }

    static func adjustHeading(
        promoting: Bool,
        source: String,
        selection: NSRange
    ) -> MarkdownEdit? {
        transformLinePrefixes(source: source, selection: selection) { lines in
            lines.map { line in
                let parsed = parseHeading(in: line.body)
                let nextLevel: Int

                if promoting {
                    nextLevel = parsed.level == 0 ? 1 : max(1, parsed.level - 1)
                } else if parsed.level == 0 || parsed.level == 6 {
                    nextLevel = 0
                } else {
                    nextLevel = parsed.level + 1
                }

                let marker = nextLevel == 0
                    ? ""
                    : String(repeating: "#", count: nextLevel) + " "
                return PrefixChange(
                    oldPrefixLength: parsed.prefixLength,
                    newPrefix: parsed.indentation + marker,
                    content: parsed.content
                )
            }
        }
    }

    static func toggleInline(
        prefix: String,
        suffix: String? = nil,
        source: String,
        selection: NSRange
    ) -> MarkdownEdit? {
        let sourceText = source as NSString
        let safeSelection = clamped(selection, to: sourceText.length)
        let closing = suffix ?? prefix
        let prefixLength = (prefix as NSString).length
        let suffixLength = (closing as NSString).length
        let selectionEnd = NSMaxRange(safeSelection)

        if safeSelection.length == 0 {
            let hasPairAroundCaret = safeSelection.location >= prefixLength
                && selectionEnd + suffixLength <= sourceText.length
                && sourceText.substring(
                    with: NSRange(
                        location: safeSelection.location - prefixLength,
                        length: prefixLength
                    )
                ) == prefix
                && sourceText.substring(
                    with: NSRange(location: selectionEnd, length: suffixLength)
                ) == closing

            if hasPairAroundCaret {
                return MarkdownEdit(
                    replacementRange: NSRange(
                        location: safeSelection.location - prefixLength,
                        length: prefixLength + suffixLength
                    ),
                    replacement: "",
                    selectionAfter: NSRange(
                        location: safeSelection.location - prefixLength,
                        length: 0
                    )
                )
            }

            return MarkdownEdit(
                replacementRange: safeSelection,
                replacement: prefix + closing,
                selectionAfter: NSRange(
                    location: safeSelection.location + prefixLength,
                    length: 0
                )
            )
        }

        let selectedText = sourceText.substring(with: safeSelection)
        let selectedNSString = selectedText as NSString
        if selectedNSString.length >= prefixLength + suffixLength,
           selectedNSString.substring(
               with: NSRange(location: 0, length: prefixLength)
           ) == prefix,
           selectedNSString.substring(
               with: NSRange(
                   location: selectedNSString.length - suffixLength,
                   length: suffixLength
               )
           ) == closing {
            let innerRange = NSRange(
                location: prefixLength,
                length: selectedNSString.length - prefixLength - suffixLength
            )
            let inner = selectedNSString.substring(with: innerRange)
            return MarkdownEdit(
                replacementRange: safeSelection,
                replacement: inner,
                selectionAfter: NSRange(location: safeSelection.location, length: innerRange.length)
            )
        }

        let hasPairOutsideSelection = safeSelection.location >= prefixLength
            && selectionEnd + suffixLength <= sourceText.length
            && sourceText.substring(
                with: NSRange(
                    location: safeSelection.location - prefixLength,
                    length: prefixLength
                )
            ) == prefix
            && sourceText.substring(
                with: NSRange(location: selectionEnd, length: suffixLength)
            ) == closing

        if hasPairOutsideSelection {
            return MarkdownEdit(
                replacementRange: NSRange(
                    location: safeSelection.location - prefixLength,
                    length: prefixLength + safeSelection.length + suffixLength
                ),
                replacement: selectedText,
                selectionAfter: NSRange(
                    location: safeSelection.location - prefixLength,
                    length: safeSelection.length
                )
            )
        }

        return MarkdownEdit(
            replacementRange: safeSelection,
            replacement: prefix + selectedText + closing,
            selectionAfter: NSRange(
                location: safeSelection.location + prefixLength,
                length: safeSelection.length
            )
        )
    }

    static func link(source: String, selection: NSRange) -> MarkdownEdit? {
        let sourceText = source as NSString
        let safeSelection = clamped(selection, to: sourceText.length)

        if safeSelection.length == 0 {
            return MarkdownEdit(
                replacementRange: safeSelection,
                replacement: "[text](https://)",
                selectionAfter: NSRange(location: safeSelection.location + 1, length: 4)
            )
        }

        let label = sourceText.substring(with: safeSelection)
        let labelLength = (label as NSString).length
        return MarkdownEdit(
            replacementRange: safeSelection,
            replacement: "[\(label)](https://)",
            selectionAfter: NSRange(
                location: safeSelection.location + labelLength + 3,
                length: 8
            )
        )
    }

    static func toggleItalic(source: String, selection: NSRange) -> MarkdownEdit? {
        let sourceText = source as NSString
        let safeSelection = clamped(selection, to: sourceText.length)
        let selectionEnd = NSMaxRange(safeSelection)

        if safeSelection.length > 0 {
            let selected = sourceText.substring(with: safeSelection) as NSString
            let leadingRun = forwardRunLength(of: 42, in: selected, from: 0)
            let trailingRun = backwardRunLength(of: 42, in: selected, before: selected.length)
            if leadingRun.isMultiple(of: 2) == false,
               trailingRun.isMultiple(of: 2) == false,
               selected.length >= 2 {
                let inner = selected.substring(
                    with: NSRange(location: 1, length: selected.length - 2)
                )
                return MarkdownEdit(
                    replacementRange: safeSelection,
                    replacement: inner,
                    selectionAfter: NSRange(
                        location: safeSelection.location,
                        length: selected.length - 2
                    )
                )
            }
        }

        let openingRun = backwardRunLength(
            of: 42,
            in: sourceText,
            before: safeSelection.location
        )
        let closingRun = forwardRunLength(
            of: 42,
            in: sourceText,
            from: selectionEnd
        )
        if openingRun.isMultiple(of: 2) == false,
           closingRun.isMultiple(of: 2) == false {
            let selected = sourceText.substring(with: safeSelection)
            return MarkdownEdit(
                replacementRange: NSRange(
                    location: safeSelection.location - 1,
                    length: safeSelection.length + 2
                ),
                replacement: selected,
                selectionAfter: NSRange(
                    location: safeSelection.location - 1,
                    length: safeSelection.length
                )
            )
        }

        let selected = sourceText.substring(with: safeSelection)
        return MarkdownEdit(
            replacementRange: safeSelection,
            replacement: "*" + selected + "*",
            selectionAfter: NSRange(
                location: safeSelection.location + 1,
                length: safeSelection.length
            )
        )
    }

    private static func forwardRunLength(
        of character: unichar,
        in source: NSString,
        from start: Int
    ) -> Int {
        var cursor = start
        while cursor < source.length, source.character(at: cursor) == character {
            cursor += 1
        }
        return cursor - start
    }

    private static func backwardRunLength(
        of character: unichar,
        in source: NSString,
        before end: Int
    ) -> Int {
        var cursor = end
        while cursor > 0, source.character(at: cursor - 1) == character {
            cursor -= 1
        }
        return end - cursor
    }

    static func toggleInlineCode(source: String, selection: NSRange) -> MarkdownEdit? {
        let sourceText = source as NSString
        let safeSelection = clamped(selection, to: sourceText.length)
        guard safeSelection.length > 0 else {
            return toggleInline(prefix: "`", source: source, selection: safeSelection)
        }

        let selected = sourceText.substring(with: safeSelection)
        if let content = inlineCodeContent(in: selected as NSString) {
            return MarkdownEdit(
                replacementRange: safeSelection,
                replacement: content,
                selectionAfter: NSRange(
                    location: safeSelection.location,
                    length: (content as NSString).length
                )
            )
        }

        if let enclosing = enclosingInlineCodeMarkers(
            in: sourceText,
            selection: safeSelection
        ) {
            return MarkdownEdit(
                replacementRange: enclosing,
                replacement: selected,
                selectionAfter: NSRange(
                    location: enclosing.location,
                    length: safeSelection.length
                )
            )
        }

        let delimiter = String(
            repeating: "`",
            count: longestBacktickRun(in: selected as NSString) + 1
        )
        let padding = selected.hasPrefix("`") || selected.hasSuffix("`") ? " " : ""
        let leadingLength = ((delimiter + padding) as NSString).length
        return MarkdownEdit(
            replacementRange: safeSelection,
            replacement: delimiter + padding + selected + padding + delimiter,
            selectionAfter: NSRange(
                location: safeSelection.location + leadingLength,
                length: safeSelection.length
            )
        )
    }

    private static func inlineCodeContent(in source: NSString) -> String? {
        var openingLength = 0
        while openingLength < source.length, source.character(at: openingLength) == 96 {
            openingLength += 1
        }
        guard openingLength > 0, source.length >= openingLength * 2 else { return nil }

        var closingStart = source.length
        while closingStart > 0, source.character(at: closingStart - 1) == 96 {
            closingStart -= 1
        }
        let closingLength = source.length - closingStart
        guard closingLength == openingLength, closingStart >= openingLength else { return nil }

        var contentRange = NSRange(
            location: openingLength,
            length: closingStart - openingLength
        )
        if contentRange.length >= 2,
           source.character(at: contentRange.location) == 32,
           source.character(at: NSMaxRange(contentRange) - 1) == 32 {
            let withoutPadding = NSRange(
                location: contentRange.location + 1,
                length: contentRange.length - 2
            )
            let candidate = source.substring(with: withoutPadding)
            if !candidate.allSatisfy({ $0 == " " }) {
                contentRange = withoutPadding
            }
        }

        return source.substring(with: contentRange)
    }

    private static func enclosingInlineCodeMarkers(
        in source: NSString,
        selection: NSRange
    ) -> NSRange? {
        var openingEnd = selection.location
        var closingStart = NSMaxRange(selection)

        if openingEnd > 0, source.character(at: openingEnd - 1) == 32 {
            openingEnd -= 1
        }
        if closingStart < source.length, source.character(at: closingStart) == 32 {
            closingStart += 1
        }

        var openingStart = openingEnd
        while openingStart > 0, source.character(at: openingStart - 1) == 96 {
            openingStart -= 1
        }
        var closingEnd = closingStart
        while closingEnd < source.length, source.character(at: closingEnd) == 96 {
            closingEnd += 1
        }

        let openingLength = openingEnd - openingStart
        let closingLength = closingEnd - closingStart
        guard openingLength > 0, openingLength == closingLength else { return nil }

        return NSRange(
            location: openingStart,
            length: closingEnd - openingStart
        )
    }

    private static func longestBacktickRun(in source: NSString) -> Int {
        var longest = 0
        var current = 0

        for location in 0..<source.length {
            if source.character(at: location) == 96 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    static func block(
        _ style: BlockStyle,
        source: String,
        selection: NSRange
    ) -> MarkdownEdit? {
        transformLinePrefixes(source: source, selection: selection) { lines in
            let parsedLines = lines.map { parseBlockPrefix(in: $0.body) }
            let meaningfulLines = parsedLines.filter {
                $0.style != nil
                    || !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            let shouldRemove = !meaningfulLines.isEmpty
                && meaningfulLines.allSatisfy { $0.style == style }
            let addMarkerToBlankLine = lines.count == 1
            var ordinal = 1

            return parsedLines.map { parsed in
                let isEmpty = parsed.content.trimmingCharacters(in: .whitespaces).isEmpty
                if isEmpty, parsed.style == nil, !addMarkerToBlankLine {
                    return PrefixChange(
                        oldPrefixLength: 0,
                        newPrefix: "",
                        content: parsed.original
                    )
                }

                let marker: String
                if shouldRemove {
                    marker = ""
                } else {
                    switch style {
                    case .quote:
                        marker = "> "
                    case .unorderedList:
                        marker = "- "
                    case .orderedList:
                        marker = "\(ordinal). "
                        if !isEmpty { ordinal += 1 }
                    case .taskList:
                        marker = "- [ ] "
                    }
                }

                return PrefixChange(
                    oldPrefixLength: parsed.prefixLength,
                    newPrefix: parsed.indentation + marker,
                    content: parsed.content
                )
            }
        }
    }

    static func fencedCode(source: String, selection: NSRange) -> MarkdownEdit? {
        let sourceText = source as NSString
        let safeSelection = clamped(selection, to: sourceText.length)

        if let fencedBlock = enclosingFencedBlock(in: source, selection: safeSelection) {
            let replacement = fencedBlock.closingLineEndingLength == 0
                ? droppingFinalLineEnding(from: fencedBlock.content)
                : fencedBlock.content
            let replacementLength = (replacement as NSString).length
            let selectionIsInside = safeSelection.location >= fencedBlock.contentRange.location
                && NSMaxRange(safeSelection) <= NSMaxRange(fencedBlock.contentRange)
            let selectionAfter: NSRange
            if selectionIsInside {
                let localStart = min(
                    replacementLength,
                    safeSelection.location - fencedBlock.contentRange.location
                )
                let localEnd = min(
                    replacementLength,
                    NSMaxRange(safeSelection) - fencedBlock.contentRange.location
                )
                selectionAfter = NSRange(
                    location: fencedBlock.fullRange.location + localStart,
                    length: max(0, localEnd - localStart)
                )
            } else {
                selectionAfter = NSRange(
                    location: fencedBlock.fullRange.location,
                    length: replacementLength
                )
            }

            return MarkdownEdit(
                replacementRange: fencedBlock.fullRange,
                replacement: replacement,
                selectionAfter: selectionAfter
            )
        }

        let targetRange = lineRange(for: safeSelection, in: sourceText)
        let target = sourceText.substring(with: targetRange)
        let lineEnding = firstLineEnding(in: target as NSString)
            ?? firstLineEnding(in: sourceText)
            ?? "\n"
        let trailingLineEnding = finalLineEnding(in: target as NSString)
        let closingSeparator = trailingLineEnding ?? lineEnding
        let trailingLength = ((trailingLineEnding ?? "") as NSString).length
        let contentRange = NSRange(
            location: 0,
            length: (target as NSString).length - trailingLength
        )
        let content = (target as NSString).substring(with: contentRange)
        let fence = String(
            repeating: "`",
            count: max(3, longestBacktickRun(in: content as NSString) + 1)
        )
        let opening = fence + lineEnding
        let openingLength = (opening as NSString).length
        let localSelectionStart = min(
            contentRange.length,
            max(0, safeSelection.location - targetRange.location)
        )
        let localSelectionEnd = min(
            contentRange.length,
            max(0, NSMaxRange(safeSelection) - targetRange.location)
        )

        return MarkdownEdit(
            replacementRange: targetRange,
            replacement: opening
                + content
                + closingSeparator
                + fence
                + (trailingLineEnding ?? ""),
            selectionAfter: NSRange(
                location: targetRange.location + openingLength + localSelectionStart,
                length: max(0, localSelectionEnd - localSelectionStart)
            )
        )
    }

    private struct FencedBlock {
        let fullRange: NSRange
        let contentRange: NSRange
        let content: String
        let closingLineEndingLength: Int
    }

    private static func enclosingFencedBlock(
        in source: String,
        selection: NSRange
    ) -> FencedBlock? {
        let sourceText = source as NSString
        var opening: (line: SourceLine, runLength: Int)?

        for line in sourceLines(in: source) {
            if opening == nil {
                guard let runLength = openingFenceRunLength(in: line.body) else { continue }
                opening = (line, runLength)
                continue
            }

            guard let openFence = opening else { continue }
            guard isClosingFence(line.body, minimumRunLength: openFence.runLength) else {
                continue
            }

            let contentStart = openFence.line.localStart
                + openFence.line.bodyLength
                + openFence.line.endingLength
            let contentEnd = line.localStart
            let contentRange = NSRange(
                location: contentStart,
                length: max(0, contentEnd - contentStart)
            )
            let selectionIsInside = selection.location >= contentRange.location
                && NSMaxRange(selection) <= NSMaxRange(contentRange)
            let fullRange = NSRange(
                location: openFence.line.localStart,
                length: line.localStart
                    + line.bodyLength
                    + line.endingLength
                    - openFence.line.localStart
            )
            let syntacticFenceEnd = line.localStart + line.bodyLength
            let selectionCoversBlock = selection.location <= fullRange.location
                && NSMaxRange(selection) >= syntacticFenceEnd

            if selectionIsInside || selectionCoversBlock {
                return FencedBlock(
                    fullRange: fullRange,
                    contentRange: contentRange,
                    content: sourceText.substring(with: contentRange),
                    closingLineEndingLength: line.endingLength
                )
            }

            opening = nil
        }

        return nil
    }

    private static func openingFenceRunLength(in line: String) -> Int? {
        let text = line as NSString
        var cursor = leadingWhitespaceLength(in: text)
        let markerStart = cursor
        while cursor < text.length, text.character(at: cursor) == 96 {
            cursor += 1
        }

        let runLength = cursor - markerStart
        guard runLength >= 3 else { return nil }
        let suffix = text.substring(from: cursor)
        return suffix.contains("`") ? nil : runLength
    }

    private static func isClosingFence(_ line: String, minimumRunLength: Int) -> Bool {
        let text = line as NSString
        var cursor = leadingWhitespaceLength(in: text)
        let markerStart = cursor
        while cursor < text.length, text.character(at: cursor) == 96 {
            cursor += 1
        }

        guard cursor - markerStart >= minimumRunLength else { return false }
        while cursor < text.length, isHorizontalWhitespace(text.character(at: cursor)) {
            cursor += 1
        }
        return cursor == text.length
    }

    private static func finalLineEnding(in source: NSString) -> String? {
        guard source.length > 0 else { return nil }
        if source.length >= 2,
           source.character(at: source.length - 2) == 13,
           source.character(at: source.length - 1) == 10 {
            return "\r\n"
        }
        if source.character(at: source.length - 1) == 13 {
            return "\r"
        }
        if source.character(at: source.length - 1) == 10 {
            return "\n"
        }
        return nil
    }

    private static func droppingFinalLineEnding(from source: String) -> String {
        let text = source as NSString
        guard let lineEnding = finalLineEnding(in: text) else { return source }
        return text.substring(
            to: text.length - (lineEnding as NSString).length
        )
    }

    private static func firstLineEnding(in source: NSString) -> String? {
        var location = 0
        while location < source.length {
            switch source.character(at: location) {
            case 13:
                if location + 1 < source.length, source.character(at: location + 1) == 10 {
                    return "\r\n"
                }
                return "\r"
            case 10:
                return "\n"
            default:
                location += 1
            }
        }
        return nil
    }

    private struct SourceLine {
        let localStart: Int
        let body: String
        let bodyLength: Int
        let ending: String
        let endingLength: Int
    }

    private struct PrefixChange {
        let oldPrefixLength: Int
        let newPrefix: String
        let content: String
    }

    private struct PositionMapping {
        let oldStart: Int
        let oldPrefixEnd: Int
        let oldBodyEnd: Int
        let oldEnd: Int
        let newStart: Int
        let newPrefixEnd: Int
        let newBodyEnd: Int
        let newEnd: Int
    }

    private struct ParsedHeading {
        let indentation: String
        let prefixLength: Int
        let content: String
        let level: Int
    }

    private struct ParsedBlockPrefix {
        let original: String
        let indentation: String
        let prefixLength: Int
        let content: String
        let style: BlockStyle?
    }

    private static func transformLinePrefixes(
        source: String,
        selection: NSRange,
        changes: ([SourceLine]) -> [PrefixChange]
    ) -> MarkdownEdit? {
        let sourceText = source as NSString
        let safeSelection = clamped(selection, to: sourceText.length)
        let targetRange = lineRange(for: safeSelection, in: sourceText)
        let target = sourceText.substring(with: targetRange)
        let lines = sourceLines(in: target)
        let prefixChanges = changes(lines)
        guard prefixChanges.count == lines.count else { return nil }

        var replacement = ""
        var mappings: [PositionMapping] = []
        var newOffset = 0

        for (line, change) in zip(lines, prefixChanges) {
            let newPrefixLength = (change.newPrefix as NSString).length
            let contentLength = (change.content as NSString).length
            replacement += change.newPrefix + change.content + line.ending
            mappings.append(
                PositionMapping(
                    oldStart: line.localStart,
                    oldPrefixEnd: line.localStart + change.oldPrefixLength,
                    oldBodyEnd: line.localStart + line.bodyLength,
                    oldEnd: line.localStart + line.bodyLength + line.endingLength,
                    newStart: newOffset,
                    newPrefixEnd: newOffset + newPrefixLength,
                    newBodyEnd: newOffset + newPrefixLength + contentLength,
                    newEnd: newOffset + newPrefixLength + contentLength + line.endingLength
                )
            )
            newOffset += newPrefixLength + contentLength + line.endingLength
        }

        let localStart = safeSelection.location - targetRange.location
        let localEnd = NSMaxRange(safeSelection) - targetRange.location
        let mappedStart = mapPosition(localStart, isSelectionEnd: false, through: mappings)
        let mappedEnd = mapPosition(localEnd, isSelectionEnd: true, through: mappings)

        return MarkdownEdit(
            replacementRange: targetRange,
            replacement: replacement,
            selectionAfter: NSRange(
                location: targetRange.location + mappedStart,
                length: max(0, mappedEnd - mappedStart)
            )
        )
    }

    private static func sourceLines(in string: String) -> [SourceLine] {
        let text = string as NSString
        if text.length == 0 {
            return [SourceLine(localStart: 0, body: "", bodyLength: 0, ending: "", endingLength: 0)]
        }

        var lines: [SourceLine] = []
        var location = 0
        while location < text.length {
            var bodyEnd = location
            while bodyEnd < text.length {
                let character = text.character(at: bodyEnd)
                if character == 10 || character == 13 { break }
                bodyEnd += 1
            }

            var lineEnd = bodyEnd
            if lineEnd < text.length {
                if text.character(at: lineEnd) == 13,
                   lineEnd + 1 < text.length,
                   text.character(at: lineEnd + 1) == 10 {
                    lineEnd += 2
                } else {
                    lineEnd += 1
                }
            }

            let bodyRange = NSRange(location: location, length: bodyEnd - location)
            let endingRange = NSRange(location: bodyEnd, length: lineEnd - bodyEnd)
            lines.append(
                SourceLine(
                    localStart: location,
                    body: text.substring(with: bodyRange),
                    bodyLength: bodyRange.length,
                    ending: text.substring(with: endingRange),
                    endingLength: endingRange.length
                )
            )
            location = lineEnd
        }

        return lines
    }

    private static func parseHeading(in line: String) -> ParsedHeading {
        let text = line as NSString
        let indentationLength = leadingWhitespaceLength(in: text)
        var cursor = indentationLength
        var level = 0

        while cursor < text.length, level < 6, text.character(at: cursor) == 35 {
            cursor += 1
            level += 1
        }

        let hasHeadingWhitespace = level > 0
            && cursor < text.length
            && isHorizontalWhitespace(text.character(at: cursor))
        if hasHeadingWhitespace {
            while cursor < text.length, isHorizontalWhitespace(text.character(at: cursor)) {
                cursor += 1
            }
        } else {
            cursor = indentationLength
            level = 0
        }

        return ParsedHeading(
            indentation: text.substring(with: NSRange(location: 0, length: indentationLength)),
            prefixLength: cursor,
            content: text.substring(from: cursor),
            level: level
        )
    }

    private static func parseBlockPrefix(in line: String) -> ParsedBlockPrefix {
        let text = line as NSString
        let indentationLength = leadingWhitespaceLength(in: text)
        var cursor = indentationLength
        var style: BlockStyle?

        if cursor < text.length,
           text.character(at: cursor) == 62,
           cursor + 1 < text.length,
           isHorizontalWhitespace(text.character(at: cursor + 1)) {
            cursor += 2
            while cursor < text.length, isHorizontalWhitespace(text.character(at: cursor)) {
                cursor += 1
            }
            style = .quote
        } else if cursor < text.length, isBullet(text.character(at: cursor)) {
            var markerEnd = cursor + 1
            if markerEnd < text.length, isHorizontalWhitespace(text.character(at: markerEnd)) {
                while markerEnd < text.length, isHorizontalWhitespace(text.character(at: markerEnd)) {
                    markerEnd += 1
                }

                if markerEnd + 3 < text.length,
                   text.character(at: markerEnd) == 91,
                   isTaskState(text.character(at: markerEnd + 1)),
                   text.character(at: markerEnd + 2) == 93,
                   isHorizontalWhitespace(text.character(at: markerEnd + 3)) {
                    markerEnd += 4
                    while markerEnd < text.length, isHorizontalWhitespace(text.character(at: markerEnd)) {
                        markerEnd += 1
                    }
                    cursor = markerEnd
                    style = .taskList
                } else {
                    cursor = markerEnd
                    style = .unorderedList
                }
            }
        } else if cursor < text.length, isDigit(text.character(at: cursor)) {
            var markerEnd = cursor
            while markerEnd < text.length, isDigit(text.character(at: markerEnd)) {
                markerEnd += 1
            }
            if markerEnd + 1 < text.length,
               (text.character(at: markerEnd) == 46 || text.character(at: markerEnd) == 41),
               isHorizontalWhitespace(text.character(at: markerEnd + 1)) {
                markerEnd += 2
                while markerEnd < text.length, isHorizontalWhitespace(text.character(at: markerEnd)) {
                    markerEnd += 1
                }
                cursor = markerEnd
                style = .orderedList
            }
        }

        if style == nil {
            cursor = indentationLength
        }

        return ParsedBlockPrefix(
            original: line,
            indentation: text.substring(with: NSRange(location: 0, length: indentationLength)),
            prefixLength: cursor,
            content: text.substring(from: cursor),
            style: style
        )
    }

    private static func lineRange(for selection: NSRange, in source: NSString) -> NSRange {
        guard source.length > 0 else { return NSRange(location: 0, length: 0) }

        var probe = selection
        if probe.length > 0 {
            probe.length -= 1
        }
        return source.lineRange(for: probe)
    }

    private static func mapPosition(
        _ position: Int,
        isSelectionEnd: Bool,
        through mappings: [PositionMapping]
    ) -> Int {
        for mapping in mappings where position >= mapping.oldStart && position <= mapping.oldEnd {
            if isSelectionEnd, position == mapping.oldStart {
                return mapping.newStart
            }
            if position <= mapping.oldPrefixEnd {
                return mapping.newPrefixEnd
            }
            if position <= mapping.oldBodyEnd {
                return mapping.newPrefixEnd + (position - mapping.oldPrefixEnd)
            }
            return mapping.newBodyEnd + (position - mapping.oldBodyEnd)
        }
        return mappings.last?.newEnd ?? 0
    }

    private static func clamped(_ range: NSRange, to length: Int) -> NSRange {
        guard range.location != NSNotFound else { return NSRange(location: 0, length: 0) }
        let location = min(max(0, range.location), length)
        return NSRange(
            location: location,
            length: min(max(0, range.length), max(0, length - location))
        )
    }

    private static func leadingWhitespaceLength(in text: NSString) -> Int {
        var length = 0
        while length < text.length, isHorizontalWhitespace(text.character(at: length)) {
            length += 1
        }
        return length
    }

    private static func isHorizontalWhitespace(_ character: unichar) -> Bool {
        character == 32 || character == 9
    }

    private static func isBullet(_ character: unichar) -> Bool {
        character == 45 || character == 42 || character == 43
    }

    private static func isTaskState(_ character: unichar) -> Bool {
        character == 32 || character == 120 || character == 88
    }

    private static func isDigit(_ character: unichar) -> Bool {
        character >= 48 && character <= 57
    }
}
