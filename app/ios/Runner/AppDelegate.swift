import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var transparencyObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "IshamelaGlass") {
      let channel = FlutterMethodChannel(
        name: "ishamela/glass",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "isAvailable":
          result(IshamelaGlassAvailability.available)
        case "reduceTransparency":
          result(UIAccessibility.isReduceTransparencyEnabled)
        case "isPowerSaveMode":
          result(ProcessInfo.processInfo.isLowPowerModeEnabled)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      let events = FlutterEventChannel(
        name: "ishamela/glass/events",
        binaryMessenger: registrar.messenger()
      )
      events.setStreamHandler(self)
      registrar.register(
        IshamelaGlassViewFactory(),
        withId: "ishamela/glass_view"
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    transparencyObserver = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.eventSink?(UIAccessibility.isReduceTransparencyEnabled)
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

enum IshamelaGlassAvailability {
  static var available: Bool {
    if ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26 {
      return false
    }
    return NSClassFromString("UIGlassEffect") != nil
  }
}

final class IshamelaGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    IshamelaGlassPlatformView(frame: frame, args: args as? [String: Any])
  }
}

final class IshamelaGlassPlatformView: NSObject, FlutterPlatformView {
  private let root: UIView

  init(frame: CGRect, args: [String: Any]?) {
    root = UIView(frame: frame)
    super.init()
    root.backgroundColor = .clear
    let radius = CGFloat((args?["radius"] as? NSNumber)?.doubleValue ?? 20)
    root.layer.cornerRadius = radius
    root.clipsToBounds = true
    if let rtl = args?["rtl"] as? Bool, rtl {
      root.semanticContentAttribute = .forceRightToLeft
    }
    guard let cls = NSClassFromString("UIGlassEffect") as? NSObject.Type else { return }
    let effect = cls.init()
    if let argb = args?["tint"] as? NSNumber {
      let raw = argb.uint32Value
      let color = UIColor(
        red: CGFloat((raw >> 16) & 0xFF) / 255,
        green: CGFloat((raw >> 8) & 0xFF) / 255,
        blue: CGFloat(raw & 0xFF) / 255,
        alpha: CGFloat((raw >> 24) & 0xFF) / 255
      )
      if effect.responds(to: Selector(("setTintColor:"))) {
        effect.setValue(color, forKey: "tintColor")
      }
    }
    if let visual = effect as? UIVisualEffect {
      let view = UIVisualEffectView(effect: visual)
      view.frame = root.bounds
      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      root.addSubview(view)
    }
  }

  func view() -> UIView { root }
}

