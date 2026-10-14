import Flutter
import UIKit

/// Blurs book content when the screen is recorded/mirrored, and while the app is
/// inactive (app switcher / background snapshot). iOS has no FLAG_SECURE.
final class ContentProtectionHandler {
  private weak var window: UIWindow?
  private var blurView: UIVisualEffectView?
  private var secureModeEnabled = false
  private var observers: [NSObjectProtocol] = []

  init(window: UIWindow?) {
    self.window = window
  }

  deinit {
    removeObservers()
  }

  func setSecureMode(_ enabled: Bool) {
    secureModeEnabled = enabled
    if enabled {
      ensureObservers()
      updateShield()
    } else {
      removeObservers()
      hideBlur()
    }
  }

  private func ensureObservers() {
    guard observers.isEmpty else { return }
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(
        forName: UIScreen.capturedDidChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.updateShield()
      }
    )
    observers.append(
      center.addObserver(
        forName: UIApplication.willResignActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.updateShield()
      }
    )
    observers.append(
      center.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.updateShield()
      }
    )
  }

  private func removeObservers() {
    let center = NotificationCenter.default
    for observer in observers {
      center.removeObserver(observer)
    }
    observers.removeAll()
  }

  private func updateShield() {
    guard secureModeEnabled else {
      hideBlur()
      return
    }
    let inactive = UIApplication.shared.applicationState != .active
    if UIScreen.main.isCaptured || inactive {
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
