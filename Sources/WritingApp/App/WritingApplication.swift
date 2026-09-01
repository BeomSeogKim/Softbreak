import AppKit

@main
@MainActor
enum WritingApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = ApplicationDelegate()

        application.setActivationPolicy(.regular)
        application.delegate = delegate

        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
