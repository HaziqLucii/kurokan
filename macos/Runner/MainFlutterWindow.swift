import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    self.setContentSize(NSSize(width: 1100, height: 720))
    self.contentMinSize = NSSize(width: 800, height: 520)
    self.title = "Kurokan"
    self.center()

    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
