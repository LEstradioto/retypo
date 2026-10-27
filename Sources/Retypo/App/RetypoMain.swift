import AppKit

@main
enum RetypoMain {
    @MainActor
    static func main() {
        LegacyDataMigration.runAtLaunch()
        _ = DotEnvLoader.load()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
