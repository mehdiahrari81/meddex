import ImageIO
import Network
import Security
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testLocalServerIdentityRejectsChangedChallengeAndMalformedProof() {
    // Public fixture signed with a disposable test key, never the actual Mac key.
    let publicKey = "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEaxfR8uEsQkf4vOblY6RA8ncDfYEt6zOg9KE5RdiYwpZP40Li/hp/m47n60p8D54WK84zV2sxXs7LtkBoN79R9Q=="
    let signature = "MEUCIBIytEBjDFmnsA8aDK/Z2TJGc8TRrIaKYam/9YMA845JAiEAq5pKBijIxygcSaQYe9sR6ne0II8CnixJGNXP09kX7Rc="
    XCTAssertTrue(LocalServerIdentityPlugin.verify(publicKey: publicKey, signature: signature,
                                                challenge: String(repeating: "a", count: 64)))
    XCTAssertFalse(LocalServerIdentityPlugin.verify(publicKey: publicKey, signature: signature,
                                                 challenge: String(repeating: "b", count: 64)))
    XCTAssertFalse(LocalServerIdentityPlugin.verify(publicKey: publicKey, signature: "invalid", challenge: "short"))
  }
  // A large, deliberately invalid login refresh verifies the full upload path
  // without reading a patient image, invoking AI, or changing account data.
  func testLargeSyntheticUploadThroughWiFi() throws {
    guard let base = ProcessInfo.processInfo.environment["MEDDEX_LIVE_API_URL"],
          let url = URL(string: base), let host = url.host else {
      throw XCTSkip("Set MEDDEX_LIVE_API_URL to run the Wi-Fi upload check")
    }
    let parameters = NWParameters.tcp
    parameters.requiredInterfaceType = .wifi
    let connection = NWConnection(host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(rawValue: UInt16(url.port ?? 8000))!, using: parameters)
    let body = String(repeating: " ", count: 1_000_000) + "{\"refresh_token\":\"invalid-engineering-upload-check\"}"
    let path = url.appendingPathComponent("auth/refresh").path
    let header = "POST \(path) HTTP/1.1\r\nHost: \(host)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nX-Request-ID: presentation-wifi-upload\r\nConnection: close\r\n\r\n"
    let completed = expectation(description: "One-megabyte upload completes on Wi-Fi")
    var finished = false
    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        connection.send(content: (header + body).data(using: .utf8), completion: .contentProcessed { error in
          XCTAssertNil(error)
          connection.receive(minimumIncompleteLength: 12, maximumLength: 4096) { data, _, _, error in
            XCTAssertNil(error)
            let response = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            XCTAssertTrue(response.hasPrefix("HTTP/1.1 401") || response.hasPrefix("HTTP/1.1 422"),
                          "Expected invalid-token rejection after receiving the synthetic body")
            if !finished { finished = true; completed.fulfill() }
          }
        })
      case .failed(let error):
        XCTFail("Wi-Fi upload failed: \(error)")
        if !finished { finished = true; completed.fulfill() }
      default: break
      }
    }
    connection.start(queue: DispatchQueue(label: "meddex.wifi.upload.qa"))
    wait(for: [completed], timeout: 40)
    connection.cancel()
  }

  // Opt-in: uses the real device's networking/ATS rules and a disposable QA login.
  // No camera images, existing account credentials, or patient data are accessed.
  func testLivePrescriptionAPIOnDevice() async throws {
    guard let base = ProcessInfo.processInfo.environment["MEDDEX_LIVE_API_URL"],
          let baseURL = URL(string: base) else {
      throw XCTSkip("Set MEDDEX_LIVE_API_URL in the test-run environment to run live API QA")
    }
    let email = "device-qa-" + UUID().uuidString.lowercased() + "@example.com"
    print("LIVE_QA_EMAIL=" + email)
    func post(_ path: String, _ body: [String: Any], token: String? = nil) async throws -> [String: Any] {
      var request = URLRequest(url: baseURL.appendingPathComponent(path))
      request.httpMethod = "POST"
      request.timeoutInterval = 110
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      let (data, response) = try await URLSession.shared.data(for: request)
      let status = try XCTUnwrap(response as? HTTPURLResponse).statusCode
      XCTAssertTrue((200..<300).contains(status), "Live endpoint \(path) returned HTTP \(status)")
      if data.isEmpty { return [:] }
      return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    let account = try await post("auth/register", [
      "email": email, "password": "TemporaryDeviceQA!" + UUID().uuidString,
      "display_name": "Temporary device connectivity QA",
    ])
    let token = try XCTUnwrap(account["access_token"] as? String)
    do {
      let parsed = try await post("prescription-ocr/structure", [
        "cloud_consent": true,
        "pages": [["page_number": 1, "text": "Rx\nLipitor 10 mg Tabs\nTake 1 tablet every day"]],
      ], token: token)
      XCTAssertEqual((parsed["medicines"] as? [[String: Any]])?.count, 1)
      let overview = try await post("prescription-ocr/medicine-overview", [
        "name": "Lipitor", "strength": "10 mg", "dosage_form": "Tabs", "language": "en",
      ], token: token)
      XCTAssertEqual(overview["status"] as? String, "available")
      XCTAssertFalse((overview["explanation"] as? [String: Any])?["answer"] as? String == nil)
      _ = try await post("auth/logout", [:], token: token)
    } catch {
      _ = try? await post("auth/logout", [:], token: token)
      throw error
    }
  }

  // The required Wi-Fi interface prevents a connected USB cable from making
  // this test pass through CoreDevice's link-local tunnel.
  func testBackendIsReachableThroughWiFiWithoutUSBNetworking() throws {
    guard let base = ProcessInfo.processInfo.environment["MEDDEX_LIVE_API_URL"],
          let url = URL(string: base), let host = url.host else {
      throw XCTSkip("Set MEDDEX_LIVE_API_URL to run the Wi-Fi route check")
    }
    let parameters = NWParameters.tcp
    parameters.requiredInterfaceType = .wifi
    let connection = NWConnection(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(rawValue: UInt16(url.port ?? 8000))!,
      using: parameters
    )
    let finished = expectation(description: "API responds over Wi-Fi")
    var completed = false
    let queue = DispatchQueue(label: "meddex.wifi.qa")
    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        XCTAssertTrue(connection.currentPath?.usesInterfaceType(.wifi) == true)
        let path = url.appendingPathComponent("ready").path
        let request = "GET \(path) HTTP/1.1\r\nHost: \(host)\r\nConnection: close\r\n\r\n"
        connection.send(content: request.data(using: .utf8), completion: .contentProcessed { error in
          XCTAssertNil(error)
          connection.receive(minimumIncompleteLength: 12, maximumLength: 4096) { data, _, _, error in
            XCTAssertNil(error)
            let response = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            XCTAssertTrue(response.hasPrefix("HTTP/1.1 200"), "Wi-Fi readiness check failed")
            if !completed { completed = true; finished.fulfill() }
          }
        })
      case .failed(let error):
        XCTFail("Wi-Fi connection failed: \(error)")
        if !completed { completed = true; finished.fulfill() }
      default: break
      }
    }
    connection.start(queue: queue)
    wait(for: [finished], timeout: 20)
    connection.cancel()
  }

  func testNativeImageNormalizationProducesReadableJPEGAndRemovesMetadata() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 60), format: format)
    let image = renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
      UIColor.black.setFill()
      context.fill(CGRect(x: 10, y: 20, width: 90, height: 8))
    }
    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
    let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
      source as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [
      kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 10.0,
                                     kCGImagePropertyGPSLatitudeRef: "N"],
    ] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let original = try XCTUnwrap(CGImageSourceCreateWithURL(source as CFURL, nil))
    let originalMetadata = CGImageSourceCopyPropertiesAtIndex(original, 0, nil) as? [String: Any]
    XCTAssertNotNil(originalMetadata?[kCGImagePropertyGPSDictionary as String])
    defer { try? FileManager.default.removeItem(at: source) }
    let result = try PrescriptionCapturePlugin.normalizedImage(at: source)
    defer { try? FileManager.default.removeItem(at: result) }
    XCTAssertEqual(result.pathExtension, "jpg")
    let decoded = try XCTUnwrap(UIImage(contentsOfFile: result.path))
    XCTAssertEqual(decoded.size.width, 120)
    XCTAssertEqual(decoded.size.height, 60)
    let properties = try XCTUnwrap(CGImageSourceCreateWithURL(result as CFURL, nil))
    let metadata = CGImageSourceCopyPropertiesAtIndex(properties, 0, nil) as? [String: Any]
    XCTAssertNil(metadata?[kCGImagePropertyGPSDictionary as String])
  }

  func testAppleVisionReadsPrintedTextWithoutACloudService() throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 180), format: format)
    let image = renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 900, height: 180))
      ("Acetaminophen 500 mg" as NSString).draw(
        at: CGPoint(x: 30, y: 40),
        withAttributes: [.font: UIFont.systemFont(ofSize: 48), .foregroundColor: UIColor.black])
    }
    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
    try XCTUnwrap(image.pngData()).write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }
    let output = try PrescriptionCapturePlugin.recognizeText(at: source)
    XCTAssertEqual(output["provider"] as? String, "apple_vision")
    let text = try XCTUnwrap(output["text"] as? String)
    XCTAssertTrue(text.contains("500 mg"))
    XCTAssertTrue(text.lowercased().contains("acetaminophen"))
  }

  func testInvalidNativeImageFailsWithoutProducingAnOutput() {
    let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    XCTAssertThrowsError(try PrescriptionCapturePlugin.normalizedImage(at: source))
  }

  func testKeychainCanPersistReadAndDeleteSessionMaterial() throws {
    let account = "qa-session-" + UUID().uuidString
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "mediexplain.session.qa",
      kSecAttrAccount as String: account,
    ]
    defer { SecItemDelete(query as CFDictionary) }
    var add = query
    add[kSecValueData as String] = Data("temporary-session-material".utf8)
    add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    XCTAssertEqual(SecItemAdd(add as CFDictionary, nil), errSecSuccess)
    var read = query
    read[kSecReturnData as String] = true
    var value: CFTypeRef?
    XCTAssertEqual(SecItemCopyMatching(read as CFDictionary, &value), errSecSuccess)
    XCTAssertEqual(value as? Data, Data("temporary-session-material".utf8))
    XCTAssertEqual(SecItemDelete(query as CFDictionary), errSecSuccess)
    XCTAssertEqual(SecItemCopyMatching(read as CFDictionary, nil), errSecItemNotFound)
  }
}
