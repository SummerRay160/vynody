import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    // Setup method channel for file opening on macOS
    let channel = FlutterMethodChannel(
      name: "vynody/file_opener",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.setupMethodChannel(channel)
    }

    super.awakeFromNib()
  }
}
