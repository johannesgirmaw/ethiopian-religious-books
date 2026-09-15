import Flutter
import UIKit

/// Blurs book content when the screen is being recorded or mirrored (iOS has no FLAG_SECURE).
final class ContentProtectionHandler {
  private weak var window: UIWindow?
  private var blurView: UIVisualEffectView?
  private var secureModeEnabled = false
  private var observer: NSObjectProtocol?

  init(window: UIWindow?) {
    self.window = window
  }

  func setSecureMode(_ enabled: Bool) {
    secureModeEnabled = enabled
    if enabled {
      if observer == nil {
        observer = NotificationCenter.default.addObserver(
          forName: UIScreen.capturedDidChangeNotification,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          self?.updateCaptureShield()
        }
      }
      updateCaptureShield()
    } else {
      if let observer {
        NotificationCenter.default.removeObserver(observer)
        self.observer = nil
      }
      hideBlur()
    }
  }

  private func updateCaptureShield() {
    guard secureModeEnabled else {
      hideBlur()
      return
    }
    if UIScreen.main.isCaptured {
      showBlur()
    } else {
      hideBlur()
    }
  }

  private func showBlur() {
    guard blurView == nil, let root = window else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    blur.frame = root.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blur.isUserInteractionEnabled = true
    root.addSubview(blur)
    blurView = blur
  }

  private func hideBlur() {
    blurView?.removeFromSuperview()
    blurView = nil
  }
}
