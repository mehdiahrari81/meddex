import AVFoundation
import CryptoKit
import Flutter
import ImageIO
import UIKit
import UserNotifications
import VisionKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MediExplainLocalServer") {
      LocalServerIdentityPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MediExplainCapture") {
      PrescriptionCapturePlugin.register(with: registrar)
    }
  }
}

final class LocalServerIdentityPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "mediexplain/local_server", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LocalServerIdentityPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "verifyIdentity" else { result(FlutterMethodNotImplemented); return }
    guard let args = call.arguments as? [String: String] else { result(false); return }
    result(Self.verify(publicKey: args["public_key"] ?? "", signature: args["signature"] ?? "",
                       challenge: args["challenge"] ?? ""))
  }

  static func verify(publicKey: String, signature: String, challenge: String) -> Bool {
    guard let key = Data(base64Encoded: publicKey),
          let signatureData = Data(base64Encoded: signature),
          challenge.count == 64 else {
      return false
    }
    do {
      let publicKey = try P256.Signing.PublicKey(derRepresentation: key)
      let proof = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
      return publicKey.isValidSignature(proof, for: Data(("mediexplain-local-server-v1\n" + challenge).utf8))
    } catch { return false }
  }
}

/// Native document edges/perspective correction and HEIC decoding without another SDK.
final class PrescriptionCapturePlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
  private var pendingScan: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "mediexplain/document_capture", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PrescriptionCapturePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "scanDocument":
      guard pendingScan == nil else {
        result(FlutterError(code: "capture_busy", message: "A scanner is already open.", details: nil))
        return
      }
      guard VNDocumentCameraViewController.isSupported else {
        result(FlutterError(code: "scanner_unavailable",
                           message: "Use a physical iPhone/iPad with a camera, or import an image.",
                           details: nil))
        return
      }
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async {
          guard let self = self else { return }
          guard granted else {
            result(FlutterError(code: "camera_denied", message: "Camera access was denied.", details: nil))
            return
          }
          guard let presenter = Self.presenter() else {
            result(FlutterError(code: "capture_unavailable", message: "No active window.", details: nil))
            return
          }
          self.pendingScan = result
          let scanner = VNDocumentCameraViewController()
          scanner.delegate = self
          presenter.present(scanner, animated: true)
        }
      }
    case "recognizeText":
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "invalid_image", message: "An image path is required.", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let recognized = try Self.recognizeText(at: URL(fileURLWithPath: path))
          DispatchQueue.main.async { result(recognized) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "ocr_failed", message: "Text recognition failed.", details: nil))
          }
        }
      }
    case "normalizeImage":
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "invalid_image", message: "An image path is required.", details: nil))
        return
      }
      let sourceURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
      guard sourceURL.path.hasPrefix(URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path + "/") else {
        result(FlutterError(code: "invalid_image", message: "Image must be inside the app sandbox.", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let output = try Self.normalizedImage(at: sourceURL)
          DispatchQueue.main.async { result(output.path) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "image_decode_failed", message: "Could not decode this image.", details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func recognizeText(at sourceURL: URL) throws -> [String: Any] {
    guard sourceURL.resolvingSymlinksInPath().path.hasPrefix(
            URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path + "/"),
          let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
          let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
      throw CaptureFailure.invalidImage
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = false // Never autocorrect a medicine name or a number.
    try VNImageRequestHandler(url: sourceURL).perform([request])
    let lines: [[String: Any]] = (request.results ?? []).compactMap { observation in
      guard let text = observation.topCandidates(1).first else { return nil }
      let box = observation.boundingBox
      return ["text": text.string, "confidence": text.confidence,
              "region": ["left": box.minX * width.doubleValue,
                         "top": (1 - box.maxY) * height.doubleValue,
                         "right": box.maxX * width.doubleValue,
                         "bottom": (1 - box.minY) * height.doubleValue]]
    }
    return ["text": lines.compactMap { $0["text"] as? String }.joined(separator: "\n"),
            "lines": lines, "provider": "apple_vision", "version": "native-v1"]
  }

  static func normalizedImage(at sourceURL: URL) throws -> URL {
    guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 3200,
          ] as CFDictionary) else { throw CaptureFailure.invalidImage }
    return try save(UIImage(cgImage: image))
  }

  private static func save(_ image: UIImage) throws -> URL {
    guard let jpeg = image.jpegData(compressionQuality: 0.92) else {
      throw CaptureFailure.invalidImage
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("prescription_work")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var url = directory.appendingPathComponent(UUID().uuidString + ".jpg")
    try jpeg.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try url.setResourceValues(values)
    return url
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                    didFinishWith scan: VNDocumentCameraScan) {
    var paths: [String] = []
    do {
      guard scan.pageCount <= 10 else { throw CaptureFailure.tooManyPages }
      for index in 0..<scan.pageCount {
        let path = try autoreleasepool { try Self.save(scan.imageOfPage(at: index)).path }
        paths.append(path)
      }
      controller.dismiss(animated: true)
      pendingScan?(paths)
    } catch {
      for path in paths { try? FileManager.default.removeItem(atPath: path) }
      controller.dismiss(animated: true)
      pendingScan?(FlutterError(code: "scan_failed",
                               message: "Scan at most 10 pages and retry.", details: nil))
    }
    pendingScan = nil
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true)
    pendingScan?([])
    pendingScan = nil
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                    didFailWithError error: Error) {
    controller.dismiss(animated: true)
    pendingScan?(FlutterError(code: "scan_failed", message: "Document scanning failed.", details: nil))
    pendingScan = nil
  }

  private static func presenter() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }

  private enum CaptureFailure: Error { case invalidImage, tooManyPages }
}
