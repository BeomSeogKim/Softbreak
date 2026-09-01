import Foundation

struct DocumentRenderRequest: Equatable, Sendable {
    let markdown: String
    let baseURL: URL?
    let theme: DocumentTheme
}
