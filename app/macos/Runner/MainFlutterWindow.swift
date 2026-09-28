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
    if ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26 {
      return false
    }
    return NSClassFromString("NSGlassEffect") != nil
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
    let root = NSView()
    root.wantsLayer = true
    let map = args as? [String: Any]
    let radius = CGFloat(truncating: (map?["radius"] as? NSNumber) ?? 20)
    root.layer?.cornerRadius = radius
    root.layer?.masksToBounds = true
    guard let cls = NSClassFromString("NSGlassEffect") as? NSObject.Type else {
      return root
    }
    let effect = cls.init()
    if let visual = effect as? NSVisualEffectView {
      visual.frame = root.bounds
      visual.autoresizingMask = [.width, .height]
      root.addSubview(visual)
    }
    return root
  }
}
