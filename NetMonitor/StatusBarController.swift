import Cocoa

/// Manages the status bar item and its dropdown menu
class StatusBarController {

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let networkMonitor: NetworkMonitor
    private let processMonitor: ProcessMonitor

    // Menu item references for updating
    private var uploadedItem: NSMenuItem!
    private var downloadedItem: NSMenuItem!
    private var durationItem: NSMenuItem!
    private var interfacesHeaderIndex: Int = 0
    private var processesHeaderIndex: Int = 0
    private var quitSeparator: NSMenuItem!
    private var interfaceItems: [NSMenuItem] = []
    private var processItems: [NSMenuItem] = []

    init(networkMonitor: NetworkMonitor, processMonitor: ProcessMonitor) {
        self.networkMonitor = networkMonitor
        self.processMonitor = processMonitor
        setupStatusItem()
        setupMenu()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use attributed string for vertical layout
            let style = NSMutableParagraphStyle()
            style.alignment = .left
            style.maximumLineHeight = 11
            style.minimumLineHeight = 11

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                .paragraphStyle: style,
                .baselineOffset: -4
            ]

            let text = "↑ --\n↓ --"
            button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
        }
    }

    private func setupMenu() {
        menu = NSMenu()

        // Session Statistics header
        let statsHeader = NSMenuItem(title: "Session Statistics", action: nil, keyEquivalent: "")
        statsHeader.isEnabled = false
        menu.addItem(statsHeader)

        // Uploaded
        uploadedItem = NSMenuItem(title: "  Uploaded: --", action: nil, keyEquivalent: "")
        uploadedItem.isEnabled = false
        menu.addItem(uploadedItem)

        // Downloaded
        downloadedItem = NSMenuItem(title: "  Downloaded: --", action: nil, keyEquivalent: "")
        downloadedItem.isEnabled = false
        menu.addItem(downloadedItem)

        // Duration
        durationItem = NSMenuItem(title: "  Duration: --", action: nil, keyEquivalent: "")
        durationItem.isEnabled = false
        menu.addItem(durationItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Interfaces header
        let interfacesHeader = NSMenuItem(title: "Interfaces", action: nil, keyEquivalent: "")
        interfacesHeader.isEnabled = false
        menu.addItem(interfacesHeader)
        interfacesHeaderIndex = menu.items.count - 1

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Processes header
        let processesHeader = NSMenuItem(title: "Active Processes", action: nil, keyEquivalent: "")
        processesHeader.isEnabled = false
        menu.addItem(processesHeader)
        processesHeaderIndex = menu.items.count - 1

        // Separator before quit
        quitSeparator = NSMenuItem.separator()
        menu.addItem(quitSeparator)

        // Quit item
        let quitItem = NSMenuItem(title: "Quit Network Monitor", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// Update the status bar and menu with current stats
    func update() {
        // Update status bar title with vertical layout
        let upSpeed = ByteFormatter.formatSpeed(networkMonitor.totalSpeedOut)
        let downSpeed = ByteFormatter.formatSpeed(networkMonitor.totalSpeedIn)

        if let button = statusItem.button {
            let style = NSMutableParagraphStyle()
            style.alignment = .left
            style.maximumLineHeight = 11
            style.minimumLineHeight = 11

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                .paragraphStyle: style,
                .baselineOffset: -4
            ]

            let text = "↑ \(upSpeed)\n↓ \(downSpeed)"
            button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
        }

        // Update session statistics
        uploadedItem.title = "  Uploaded: \(ByteFormatter.formatBytes(networkMonitor.sessionBytesOut))"
        downloadedItem.title = "  Downloaded: \(ByteFormatter.formatBytes(networkMonitor.sessionBytesIn))"
        durationItem.title = "  Duration: \(ByteFormatter.formatDuration(networkMonitor.sessionDuration))"

        // Update interfaces - remove old interface items first
        for item in interfaceItems {
            menu.removeItem(item)
        }
        interfaceItems.removeAll()

        // Add current interface items - only show active interfaces
        let interfaces = networkMonitor.activeInterfaces.filter { $0.speedIn > 100 || $0.speedOut > 100 }
        let insertIndex = interfacesHeaderIndex + 1

        if interfaces.isEmpty {
            let item = NSMenuItem(title: "  No active interfaces", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.insertItem(item, at: insertIndex)
            interfaceItems.append(item)
        } else {
            for (index, iface) in interfaces.enumerated() {
                let upSpeed = ByteFormatter.formatSpeed(iface.speedOut)
                let downSpeed = ByteFormatter.formatSpeed(iface.speedIn)
                let title = "  \(iface.displayName): ↑ \(upSpeed) ↓ \(downSpeed)"

                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.insertItem(item, at: insertIndex + index)
                interfaceItems.append(item)
            }
        }

        // Update processes - remove old process items first
        for item in processItems {
            menu.removeItem(item)
        }
        processItems.removeAll()

        // Recalculate processesHeaderIndex after interface items changed
        let currentProcessesHeaderIndex = interfacesHeaderIndex + 1 + interfaceItems.count + 1  // +1 for separator
        let processInsertIndex = currentProcessesHeaderIndex + 1

        let processes = processMonitor.topProcesses
        if processes.isEmpty {
            let item = NSMenuItem(title: "  No active processes", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.insertItem(item, at: processInsertIndex)
            processItems.append(item)
        } else {
            for (index, proc) in processes.enumerated() {
                let item = NSMenuItem()
                item.isEnabled = false

                let upSpeed = ByteFormatter.formatSpeed(proc.speedOut)
                let downSpeed = ByteFormatter.formatSpeed(proc.speedIn)

                if proc.isActive {
                    item.title = "  \(proc.name): ↑ \(upSpeed) ↓ \(downSpeed)"
                } else {
                    // Gray out inactive processes - show last speeds with (idle)
                    let title = "  \(proc.name): ↑ \(upSpeed) ↓ \(downSpeed) (idle)"
                    let attributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: NSColor.gray,
                        .font: NSFont.menuFont(ofSize: 0)
                    ]
                    item.attributedTitle = NSAttributedString(string: title, attributes: attributes)
                }

                menu.insertItem(item, at: processInsertIndex + index)
                processItems.append(item)
            }
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
