import AppKit

@MainActor
enum MainMenuFactory {
    static func makeMainMenu(
        for application: NSApplication,
        documentController: MarkdownDocumentController,
        recentDocumentsMenuCoordinator: RecentDocumentsMenuCoordinator
    ) -> NSMenu {
        let applicationName = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleDisplayName"
        ) as? String ?? ProcessInfo.processInfo.processName

        let mainMenu = NSMenu(title: "Main Menu")
        mainMenu.addSubmenu(
            makeApplicationMenu(named: applicationName, application: application),
            titled: applicationName
        )
        mainMenu.addSubmenu(
            makeFileMenu(
                documentController: documentController,
                recentDocumentsMenuCoordinator: recentDocumentsMenuCoordinator
            ),
            titled: "File"
        )
        mainMenu.addSubmenu(makeEditMenu(), titled: "Edit")
        mainMenu.addSubmenu(makeViewMenu(), titled: "View")

        let windowMenu = makeWindowMenu(application: application)
        mainMenu.addSubmenu(windowMenu, titled: "Window")
        application.windowsMenu = windowMenu

        return mainMenu
    }

    private static func makeApplicationMenu(
        named applicationName: String,
        application: NSApplication
    ) -> NSMenu {
        let menu = NSMenu(title: applicationName)
        menu.addItem(
            item(
                titled: "About \(applicationName)",
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                target: application
            )
        )
        menu.addItem(.separator())

        let servicesMenu = NSMenu(title: "Services")
        let servicesItem = item(titled: "Services")
        menu.addItem(servicesItem)
        menu.setSubmenu(servicesMenu, for: servicesItem)
        application.servicesMenu = servicesMenu

        menu.addItem(.separator())
        menu.addItem(
            item(
                titled: "Hide \(applicationName)",
                action: #selector(NSApplication.hide(_:)),
                keyEquivalent: "h",
                target: application
            )
        )
        menu.addItem(
            item(
                titled: "Hide Others",
                action: #selector(NSApplication.hideOtherApplications(_:)),
                keyEquivalent: "h",
                modifiers: [.command, .option],
                target: application
            )
        )
        menu.addItem(
            item(
                titled: "Show All",
                action: #selector(NSApplication.unhideAllApplications(_:)),
                target: application
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            item(
                titled: "Quit \(applicationName)",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q",
                target: application
            )
        )

        return menu
    }

    private static func makeFileMenu(
        documentController: MarkdownDocumentController,
        recentDocumentsMenuCoordinator: RecentDocumentsMenuCoordinator
    ) -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(
            item(
                titled: "New",
                action: #selector(NSDocumentController.newDocument(_:)),
                keyEquivalent: "n",
                target: documentController
            )
        )
        menu.addItem(
            item(
                titled: "Open…",
                action: #selector(NSDocumentController.openDocument(_:)),
                keyEquivalent: "o",
                target: documentController
            )
        )

        let openRecentItem = item(titled: "Open Recent")
        menu.addItem(openRecentItem)
        menu.setSubmenu(recentDocumentsMenuCoordinator.menu, for: openRecentItem)

        menu.addItem(.separator())
        menu.addItem(
            item(
                titled: "Close",
                action: #selector(NSWindow.performClose(_:)),
                keyEquivalent: "w"
            )
        )
        menu.addItem(
            item(
                titled: "Save",
                action: #selector(NSDocument.save(_:)),
                keyEquivalent: "s"
            )
        )
        menu.addItem(
            item(
                titled: "Save As…",
                action: #selector(NSDocument.saveAs(_:)),
                keyEquivalent: "s",
                modifiers: [.command, .shift]
            )
        )
        menu.addItem(
            item(
                titled: "Revert to Saved",
                action: #selector(NSDocument.revertToSaved(_:))
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            item(
                titled: "Export PDF…",
                action: #selector(EditorWindowController.exportPDF(_:)),
                keyEquivalent: "e",
                modifiers: [.command, .shift]
            )
        )

        return menu
    }

    private static func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(
            item(
                titled: "Undo",
                action: Selector(("undo:")),
                keyEquivalent: "z"
            )
        )
        menu.addItem(
            item(
                titled: "Redo",
                action: Selector(("redo:")),
                keyEquivalent: "z",
                modifiers: [.command, .shift]
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            item(
                titled: "Cut",
                action: #selector(NSText.cut(_:)),
                keyEquivalent: "x"
            )
        )
        menu.addItem(
            item(
                titled: "Copy",
                action: #selector(NSText.copy(_:)),
                keyEquivalent: "c"
            )
        )
        menu.addItem(
            item(
                titled: "Paste",
                action: #selector(NSText.paste(_:)),
                keyEquivalent: "v"
            )
        )
        menu.addItem(
            item(
                titled: "Paste and Match Style",
                action: #selector(NSTextView.pasteAsPlainText(_:)),
                keyEquivalent: "v",
                modifiers: [.command, .option, .shift]
            )
        )
        menu.addItem(
            item(
                titled: "Select All",
                action: #selector(NSText.selectAll(_:)),
                keyEquivalent: "a"
            )
        )
        menu.addItem(.separator())

        let findItem = item(titled: "Find")
        let findMenu = makeFindMenu()
        menu.addItem(findItem)
        menu.setSubmenu(findMenu, for: findItem)

        menu.addItem(.separator())
        menu.addItem(
            item(
                titled: "Emoji & Symbols",
                action: #selector(NSApplication.orderFrontCharacterPalette(_:)),
                keyEquivalent: " ",
                modifiers: [.command, .control],
                target: NSApplication.shared
            )
        )

        return menu
    }

    private static func makeFindMenu() -> NSMenu {
        let menu = NSMenu(title: "Find")

        let find = item(
            titled: "Find…",
            action: #selector(NSTextView.performFindPanelAction(_:)),
            keyEquivalent: "f"
        )
        find.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        menu.addItem(find)

        let findNext = item(
            titled: "Find Next",
            action: #selector(NSTextView.performFindPanelAction(_:)),
            keyEquivalent: "g"
        )
        findNext.tag = Int(NSFindPanelAction.next.rawValue)
        menu.addItem(findNext)

        let findPrevious = item(
            titled: "Find Previous",
            action: #selector(NSTextView.performFindPanelAction(_:)),
            keyEquivalent: "g",
            modifiers: [.command, .shift]
        )
        findPrevious.tag = Int(NSFindPanelAction.previous.rawValue)
        menu.addItem(findPrevious)

        let useSelection = item(
            titled: "Use Selection for Find",
            action: #selector(NSTextView.performFindPanelAction(_:)),
            keyEquivalent: "e"
        )
        useSelection.tag = Int(NSFindPanelAction.setFindString.rawValue)
        menu.addItem(useSelection)

        return menu
    }

    private static func makeViewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        menu.addItem(
            item(
                titled: "Write",
                action: #selector(EditorWindowController.showWriteMode(_:)),
                keyEquivalent: "1"
            )
        )
        menu.addItem(
            item(
                titled: "Read",
                action: #selector(EditorWindowController.showReadMode(_:)),
                keyEquivalent: "2"
            )
        )
        menu.addItem(
            item(
                titled: "PDF Preview",
                action: #selector(EditorWindowController.showPDFMode(_:)),
                keyEquivalent: "3"
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            item(
                titled: "Enter Full Screen",
                action: #selector(NSWindow.toggleFullScreen(_:)),
                keyEquivalent: "f",
                modifiers: [.command, .control]
            )
        )

        return menu
    }

    private static func makeWindowMenu(application: NSApplication) -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(
            item(
                titled: "Minimize",
                action: #selector(NSWindow.performMiniaturize(_:)),
                keyEquivalent: "m"
            )
        )
        menu.addItem(
            item(
                titled: "Zoom",
                action: #selector(NSWindow.performZoom(_:))
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            item(
                titled: "Bring All to Front",
                action: #selector(NSApplication.arrangeInFront(_:)),
                target: application
            )
        )

        return menu
    }

    private static func item(
        titled title: String,
        action: Selector? = nil,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: keyEquivalent
        )
        item.keyEquivalentModifierMask = keyEquivalent.isEmpty ? [] : modifiers
        item.target = target
        return item
    }
}

private extension NSMenu {
    func addSubmenu(_ submenu: NSMenu, titled title: String) {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        addItem(menuItem)
        setSubmenu(submenu, for: menuItem)
    }
}

@MainActor
final class RecentDocumentsMenuCoordinator: NSObject, NSMenuDelegate {
    let menu = NSMenu(title: "Open Recent")

    private let documentController: MarkdownDocumentController

    init(documentController: MarkdownDocumentController) {
        self.documentController = documentController
        super.init()
        menu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let recentURLs = documentController.recentDocumentURLs
        if recentURLs.isEmpty {
            let emptyItem = NSMenuItem(
                title: "No Recent Documents",
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for url in recentURLs {
                let recentItem = NSMenuItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    action: #selector(openRecentDocument(_:)),
                    keyEquivalent: ""
                )
                recentItem.representedObject = url
                recentItem.toolTip = url.path
                recentItem.target = self
                menu.addItem(recentItem)
            }
        }

        menu.addItem(.separator())
        let clearItem = NSMenuItem(
            title: "Clear Menu",
            action: #selector(NSDocumentController.clearRecentDocuments(_:)),
            keyEquivalent: ""
        )
        clearItem.target = documentController
        menu.addItem(clearItem)
    }

    @objc
    private func openRecentDocument(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }

        documentController.openDocument(
            withContentsOf: url,
            display: true
        ) { [weak documentController] _, _, error in
            if let error {
                documentController?.presentError(error)
            }
        }
    }
}
