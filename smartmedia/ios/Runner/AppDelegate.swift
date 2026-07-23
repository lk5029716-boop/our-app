import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let channelName = "com.smartmedia.app/keyboard_bridge"
    private let engine = MediaEngineIOS()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: channelName,
                binaryMessenger: controller.binaryMessenger
            )
            channel.setMethodCallHandler { [weak self] call, result in
                self?.handle(call: call, result: result)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getContentMimeTypes":
            // iOS keyboard does not expose EditorInfo MIME list; dual-write covers it.
            result([] as [String])

        case "downloadToCache":
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String else {
                result(FlutterError(code: "bad_args", message: "url required", details: nil))
                return
            }
            Task {
                do {
                    let file = try await engine.downloadToCache(url)
                    result(file.path)
                } catch {
                    result(FlutterError(code: "download_failed", message: error.localizedDescription, details: nil))
                }
            }

        case "transcodeGifToMp4":
            guard let args = call.arguments as? [String: Any],
                  let path = args["inputPath"] as? String else {
                result(FlutterError(code: "bad_args", message: "inputPath required", details: nil))
                return
            }
            Task {
                do {
                    let out = try await engine.transcodeGifToMp4(URL(fileURLWithPath: path))
                    result(out.path)
                } catch {
                    result(FlutterError(code: "transcode_failed", message: error.localizedDescription, details: nil))
                }
            }

        case "writeDualPasteboard":
            guard let args = call.arguments as? [String: Any],
                  let gifPath = args["gifPath"] as? String else {
                result(FlutterError(code: "bad_args", message: "gifPath required", details: nil))
                return
            }
            let mp4Path = args["mp4Path"] as? String
            let ok = engine.writeDualPasteboard(
                gif: URL(fileURLWithPath: gifPath),
                mp4: mp4Path.map { URL(fileURLWithPath: $0) }
            )
            result(ok)

        case "commitContent":
            // Map to dual pasteboard on iOS
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(false)
                return
            }
            let mime = (args["mimeType"] as? String) ?? "image/gif"
            if mime.contains("gif") {
                result(engine.writeDualPasteboard(gif: URL(fileURLWithPath: path), mp4: nil))
            } else {
                // Treat as mp4-only write
                let gifDummy = URL(fileURLWithPath: path)
                result(engine.writeDualPasteboard(gif: gifDummy, mp4: URL(fileURLWithPath: path)))
            }

        case "openShareSheet":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String,
                  let root = window?.rootViewController else {
                result(false)
                return
            }
            let url = URL(fileURLWithPath: path)
            let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            root.present(vc, animated: true)
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
