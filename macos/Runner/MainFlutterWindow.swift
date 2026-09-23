import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // Title bar transparency + full-size content view are handled by the
    // macos_window_utils plugin from Dart (main.dart). On macOS 26+ a
    // confirmed Apple bug (FB20341654) still renders the title bar
    // background despite this; that's an OS-level issue, not fixable here.
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    self.setContentSize(NSSize(width: 1100, height: 720))
    self.contentMinSize = NSSize(width: 800, height: 520)
    self.title = "Kurokan"
    self.center()
    self.isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
