import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var networkMonitor: NetworkMonitor!
    private var processMonitor: ProcessMonitor!
    private var statusBarController: StatusBarController!
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize monitors
        networkMonitor = NetworkMonitor()
        processMonitor = ProcessMonitor()

        // Initialize status bar controller
        statusBarController = StatusBarController(networkMonitor: networkMonitor, processMonitor: processMonitor)

        // Start update timer (1 second interval)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }

        // Ensure timer runs even when menu is open
        RunLoop.current.add(updateTimer!, forMode: .common)

        // Initial update
        updateStats()
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateStats() {
        DispatchQueue.main.async { [weak self] in
            self?.networkMonitor.update()
            self?.processMonitor.update()
            self?.statusBarController.update()
        }
    }
}
