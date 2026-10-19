import AppKit
import Vision

/// Dev tools: screenshot, screen recording, OCR text extraction.
enum DevTools {

    // MARK: - Screenshot (uses built-in screencapture CLI)

    static func captureScreenshot() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-c"] // interactive + copy to clipboard
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Screen recording (opens QuickTime-style via screencapture)

    static func recordScreen() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-v", "-i"] // video + interactive region
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - OCR

    /// Extract text from the clipboard image using Vision (macOS 10.15+).
    static func ocrClipboard(completion: @escaping (String?) -> Void) {
        guard let image = NSImage(pasteboard: .general) else {
            completion(nil)
            return
        }
        ocr(image: image, completion: completion)
    }

    static func ocr(image: NSImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }

        let request = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            let text = observations.compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            completion(text.isEmpty ? nil : text)
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}
