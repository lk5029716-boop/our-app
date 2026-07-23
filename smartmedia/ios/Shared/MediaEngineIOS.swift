import Foundation
import UIKit
import UniformTypeIdentifiers
import MobileCoreServices
import AVFoundation

/**
 * Local transcoding + dual pasteboard writer for iOS keyboard extension.
 *
 * FFmpeg command (product spec):
 * ffmpeg -y -stream_loop 3 -i input.gif -c:v libx264 -pix_fmt yuv420p
 *   -movflags faststart -vf scale='trunc(iw/2)*2:trunc(ih/2)*2' output.mp4
 *
 * Production: link mobile-ffmpeg / ffmpeg-kit iOS XCFramework and invoke
 * FFmpegKit.execute. Below includes a pure-AVFoundation fallback encoder
 * so the project compiles without the binary dependency in CI sandboxes.
 */
final class MediaEngineIOS {

    private var cacheDir: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("smartmedia", isDirectory: true)
    }

    init() {
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    /// Chunk-stream remote GIF into temporary sandbox cache.
    func downloadToCache(_ gifUrl: String) async throws -> URL {
        guard let remote = URL(string: gifUrl) else {
            throw EngineError.badURL
        }
        let (data, response) = try await URLSession.shared.data(from: remote)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw EngineError.downloadFailed
        }
        let dest = cacheDir.appendingPathComponent("sm_\(UUID().uuidString).gif")
        try data.write(to: dest, options: .atomic)
        return dest
    }

    /**
     * Prefer FFmpegKit when linked; otherwise AVFoundation still-image sequence
     * encoder that approximates the same even-dimension H.264 + faststart intent.
     */
    func transcodeGifToMp4(_ inputGif: URL) async throws -> URL {
        #if canImport(ffmpegkit)
        return try await transcodeWithFFmpegKit(inputGif)
        #else
        return try await transcodeWithAVFoundation(inputGif)
        #endif
    }

    #if canImport(ffmpegkit)
    private func transcodeWithFFmpegKit(_ inputGif: URL) async throws -> URL {
        let output = cacheDir.appendingPathComponent("sm_\(UUID().uuidString).mp4")
        let cmd = """
        -y -stream_loop 3 -i "\(inputGif.path)" -c:v libx264 -pix_fmt yuv420p -movflags faststart -vf scale='trunc(iw/2)*2:trunc(ih/2)*2' "\(output.path)"
        """
        return try await withCheckedThrowingContinuation { cont in
            FFmpegKit.executeAsync(cmd) { session in
                guard let session, ReturnCode.isSuccess(session.getReturnCode()) else {
                    cont.resume(throwing: EngineError.transcodeFailed)
                    return
                }
                cont.resume(returning: output)
            }
        }
    }
    #endif

    /// AVFoundation fallback — encodes first GIF frame looped as short H.264 clip.
    private func transcodeWithAVFoundation(_ inputGif: URL) async throws -> URL {
        guard let source = CGImageSourceCreateWithURL(inputGif as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw EngineError.transcodeFailed
        }

        var width = cg.width
        var height = cg.height
        // Enforce even dimensions (H.264 requirement)
        if width % 2 != 0 { width -= 1 }
        if height % 2 != 0 { height -= 1 }
        if width < 2 || height < 2 { throw EngineError.transcodeFailed }

        let output = cacheDir.appendingPathComponent("sm_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: output)

        let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // ~3 loops × ~10 frames ≈ short endless-feel clip
        let frameCount = 30
        let fps: Int32 = 10
        for i in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            if let pb = pixelBuffer(from: cg, width: width, height: height) {
                let time = CMTime(value: CMTimeValue(i), timescale: fps)
                adaptor.append(pb, withPresentationTime: time)
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw EngineError.transcodeFailed
        }
        return output
    }

    private func pixelBuffer(from image: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                            kCVPixelFormatType_32ARGB, attrs as CFDictionary, &buffer)
        guard let pb = buffer else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pb
    }

    /**
     * Concurrently write GIF + MPEG-4 onto UIPasteboard.
     * Host app natively matches whichever type it supports on paste.
     */
    @discardableResult
    func writeDualPasteboard(gif: URL, mp4: URL?) -> Bool {
        guard let gifData = try? Data(contentsOf: gif) else { return false }
        var items: [[String: Any]] = []

        var gifItem: [String: Any] = [:]
        if #available(iOS 14.0, *) {
            gifItem[UTType.gif.identifier] = gifData
        } else {
            gifItem[kUTTypeGIF as String] = gifData
        }
        items.append(gifItem)

        if let mp4, let mp4Data = try? Data(contentsOf: mp4) {
            var mp4Item: [String: Any] = [:]
            if #available(iOS 14.0, *) {
                mp4Item[UTType.mpeg4Movie.identifier] = mp4Data
            } else {
                mp4Item[kUTTypeMPEG4 as String] = mp4Data
            }
            items.append(mp4Item)
        }

        // Also set multi-representation single pasteboard item when possible
        var combined: [String: Any] = [:]
        if #available(iOS 14.0, *) {
            combined[UTType.gif.identifier] = gifData
            if let mp4, let mp4Data = try? Data(contentsOf: mp4) {
                combined[UTType.mpeg4Movie.identifier] = mp4Data
            }
        } else {
            combined[kUTTypeGIF as String] = gifData
            if let mp4, let mp4Data = try? Data(contentsOf: mp4) {
                combined[kUTTypeMPEG4 as String] = mp4Data
            }
        }

        let board = UIPasteboard.general
        board.items = [combined]
        return true
    }

    enum EngineError: Error {
        case badURL, downloadFailed, transcodeFailed
    }
}
