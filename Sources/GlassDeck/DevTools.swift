import AppKit
import Vision

/// Dev tools: screenshot, screen recording, OCR text extraction.
enum DevTools {

    // MARK: - Shared runner

    /// `screencapture` in interactive mode stays alive until the user either
    /// takes the shot or presses Esc — seconds to minutes. It used to be run on
    /// the main thread with `waitUntilExit()`, which froze the whole app with no
    /// hint that anything was happening. Now it runs on a background queue and
    /// reports back exactly once.
    private static func runScreencapture(_ args: [String],
                                         completion: @escaping (String?) -> Void) {
        guard PermissionCenter.screenRecording() else {
            // Triggers the system prompt so the app lands in the Screen
            // Recording list instead of failing silently forever.
            PermissionCenter.requestScreenRecording()
            DispatchQueue.main.async {
                completion(L.t(.screenRecordingNeeded))
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = args
            let errPipe = Pipe()
            process.standardError = errPipe
            process.standardOutput = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                DispatchQueue.main.async { completion(error.localizedDescription) }
                return
            }
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                DispatchQueue.main.async {
                    completion(message.isEmpty ? "screencapture exit \(process.terminationStatus)" : message)
                }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // MARK: - Screenshot (built-in screencapture CLI, straight to clipboard)

    static func captureScreenshot(completion: @escaping (String?) -> Void) {
        runScreencapture(["-i", "-c", "-x"], completion: completion)
    }

    // MARK: - Screen recording

    /// Starts the interactive video recording UI with its toolbar. Recording
    /// keeps going until the user presses Stop; the file lands wherever macOS
    /// saves screen recordings (Desktop by default).
    static func recordScreen(completion: @escaping (String?) -> Void) {
        runScreencapture(["-v", "-i", "-U"], completion: completion)
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
