import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Implemented in Dart by `lib/utils/file_manager.dart`.
  private static let finderChannelName = "de.finanzgecko.app/finder"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MainFlutterWindow.registerFinderChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  // WARNING: this channel exists because `url_launcher` cannot do the job under the App Sandbox.
  // Opening a `file:` URL goes through `NSWorkspace.open`, which reads properties of the URL — and for
  // anything outside the container the sandbox refuses that. macOS then shows "… hat keine Berechtigung,
  // den Ordner „Downloads“ zu öffnen" and NSWorkspace, unlike a file dialog, never raises a Powerbox
  // prompt, so the user is offered nothing to grant. Apple DTS names `activateFileViewerSelecting` as the
  // sandbox-safe route; it works on any URL the app already holds an extension for, which the file just
  // saved through NSSavePanel is. Hence two methods: revealing a FILE and opening a FOLDER are not
  // interchangeable here — see dev/ai/platform.md.
  private static func registerFinderChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: finderChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let path = (call.arguments as? [String: Any])?["path"] as? String, !path.isEmpty else {
        result(FlutterError(code: "invalid-arguments", message: "path missing or empty", details: nil))
        return
      }
      switch call.method {
      case "revealFile":
        // Selects the file in Finder. Needs no file-access entitlement: the app inherited a Powerbox
        // extension for exactly this path when the user picked it in the save dialog.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue
        else {
          result(false)
          return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        result(true)
      case "openFolder":
        // INFO: only ever called for the app's own data directory, which is inside the container —
        // `NSWorkspace.open` is allowed there. Do not point this at a user-chosen folder.
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue
        else {
          result(false)
          return
        }
        result(NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true)))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
