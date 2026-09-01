import CoreGraphics
import Foundation
import PDFKit

actor PDFPageBackgroundRenderer {
    func render(sourceURL: URL, backgroundHex: String) throws -> URL {
        try Task.checkCancellation()

        guard
            let sourceDocument = CGPDFDocument(sourceURL as CFURL),
            let sourcePDFDocument = PDFDocument(url: sourceURL),
            sourceDocument.numberOfPages > 0,
            sourcePDFDocument.pageCount == sourceDocument.numberOfPages,
            let firstPage = sourceDocument.page(at: 1)
        else {
            throw PDFPageBackgroundRenderingError.invalidSource
        }

        let backgroundColor = try color(from: backgroundHex)
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WritingApp-Themed-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
        var mediaBox = firstPage.getBoxRect(.mediaBox)

        guard let context = CGContext(
            destinationURL as CFURL,
            mediaBox: &mediaBox,
            nil
        ) else {
            throw PDFPageBackgroundRenderingError.renderingFailed
        }

        var contextIsClosed = false
        var shouldKeepDestination = false
        defer {
            if !contextIsClosed {
                context.closePDF()
            }
            if !shouldKeepDestination {
                try? FileManager.default.removeItem(at: destinationURL)
            }
        }

        for pageIndex in 1...sourceDocument.numberOfPages {
            try Task.checkCancellation()
            guard
                let page = sourceDocument.page(at: pageIndex),
                let sourcePDFPage = sourcePDFDocument.page(at: pageIndex - 1)
            else {
                throw PDFPageBackgroundRenderingError.renderingFailed
            }

            context.beginPDFPage(nil)
            context.setFillColor(backgroundColor)
            context.fill(mediaBox)
            context.drawPDFPage(page)

            for annotation in sourcePDFPage.annotations {
                try Task.checkCancellation()
                guard let url = (annotation.action as? PDFActionURL)?.url
                    ?? annotation.url
                else {
                    continue
                }

                context.setURL(url as CFURL, for: annotation.bounds)
            }
            context.endPDFPage()
        }

        context.closePDF()
        contextIsClosed = true
        try Task.checkCancellation()

        guard
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: destinationURL.path
            ),
            let byteCount = attributes[.size] as? NSNumber,
            byteCount.intValue > 0,
            let renderedDocument = PDFDocument(url: destinationURL),
            renderedDocument.pageCount == sourceDocument.numberOfPages
        else {
            throw PDFPageBackgroundRenderingError.invalidOutput
        }

        shouldKeepDestination = true
        return destinationURL
    }

    private func color(from hex: String) throws -> CGColor {
        let digits = hex.dropFirst()
        guard
            digits.count == 6,
            let value = UInt32(digits, radix: 16),
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let color = CGColor(
                colorSpace: colorSpace,
                components: [
                    CGFloat((value >> 16) & 0xFF) / 255,
                    CGFloat((value >> 8) & 0xFF) / 255,
                    CGFloat(value & 0xFF) / 255,
                    1,
                ]
            )
        else {
            throw PDFPageBackgroundRenderingError.invalidColor
        }

        return color
    }
}

private enum PDFPageBackgroundRenderingError: LocalizedError {
    case invalidSource
    case invalidOutput
    case invalidColor
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .invalidSource, .invalidOutput:
            "The generated PDF could not be opened."
        case .invalidColor, .renderingFailed:
            "The document theme could not be applied to the PDF pages."
        }
    }
}
