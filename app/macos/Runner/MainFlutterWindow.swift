import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let glassBridge = IshamelaMacGlassBridge()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    glassBridge.register(with: flutterViewController.registrar(forPlugin: "IshamelaGlass"))

    super.awakeFromNib()
  }
}

final class IshamelaMacGlassBridge: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var transparencyObserver: NSObjectProtocol?

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ishamela/glass",
      binaryMessenger: registrar.messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(self.glassAvailable)
      case "reduceTransparency":
        result(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
      case "isPowerSaveMode":
        if #available(macOS 12.0, *) {
          result(ProcessInfo.processInfo.isLowPowerModeEnabled)
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let events = FlutterEventChannel(
      name: "ishamela/glass/events",
      binaryMessenger: registrar.messenger
    )
    events.setStreamHandler(self)
    registrar.register(
      IshamelaMacGlassViewFactory(),
      withId: "ishamela/glass_view"
    )
  }

  private var glassAvailable: Bool {
    if #available(macOS 26.0, *) {
      return true
    }
    return false
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    transparencyObserver = NotificationCenter.default.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.eventSink?(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let transparencyObserver {
      NotificationCenter.default.removeObserver(transparencyObserver)
    }
    transparencyObserver = nil
    eventSink = nil
    return nil
  }
}

final class IshamelaMacGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> (any FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withViewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> NSView {
    let map = args as? [String: Any]
    let radius = CGFloat(truncating: (map?["radius"] as? NSNumber) ?? 20)
    let tint = (map?["tint"] as? NSNumber)?.uint32Value ?? 0
    if #available(macOS 26.0, *) {
      let glass = NSGlassEffectView()
      glass.cornerRadius = radius
      glass.style = .regular
      glass.tintColor = Self.color(argb: tint)
      return glass
    }
    let root = NSView()
    root.wantsLayer = true
    return root
  }

  private static func color(argb: UInt32) -> NSColor {
    NSColor(
      srgbRed: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }
}
