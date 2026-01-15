import AVFoundation
import Foundation
import AppKit

@available(macOS 14.4, *)
final class TranscriptionController {
    private let notchView: NotchView
    private let sendQueue = DispatchQueue(label: "transcribtion.scribe.send")
    private let audioCaptureQueue = DispatchQueue(label: "transcribtion.audio.capture")
    private var audioConverter: AVAudioConverter?
    private var systemAudioTap: SystemAudioTap?
    private var webSocket: URLSessionWebSocketTask?
    private var committedText = ""
    private var partialText = ""
    private var isSessionReady = false
    private var lastCommitTime: Date?
    private var isListening = false
    private var apiKey: String?
    private var didShowAuthError = false

    private let targetSampleRate: Double = 16_000
    private let targetChannels: AVAudioChannelCount = 1

    init(notchView: NotchView) {
        self.notchView = notchView
    }

    func start() {
        resumeListening()
    }

    func resumeListening() {
        guard !isListening else { return }
        guard let apiKey = apiKey ?? EnvLoader.loadApiKey() else {
            presentTokenPrompt { [weak self] token in
                guard let self else { return }
                guard let token, !token.isEmpty else {
                    self.logError("Missing ELEVENLABS_API_KEY.")
                    self.alertMissingTokenAndQuit()
                    return
                }
                EnvLoader.saveApiKey(token)
                self.apiKey = token
                self.resumeListening()
            }
            return
        }

        didShowAuthError = false
        self.apiKey = apiKey
        self.isListening = true
        self.isSessionReady = false
        self.connectWebSocket(apiKey: apiKey)
        self.startAudioCapture()
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        isSessionReady = false
        stopAudioCapture()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        updateUI("Paused")
    }

    func clearTranscription() {
        committedText = ""
        partialText = ""
        updateUI("Listening...")
    }

    func insertTabMarker() {
        let marker = NotchView.markerToken
        let prefix = committedText.isEmpty ? "" : " "
        committedText = committedText + prefix + marker + " "
        committedText = trimIfNeeded(committedText)
        updateUI(currentDisplayText())
    }

    private func connectWebSocket(apiKey: String) {
        let baseURL = "wss://api.elevenlabs.io/v1/speech-to-text/realtime"
        let query = [
            "model_id=scribe_v2_realtime",
            "audio_format=pcm_16000",
            "commit_strategy=vad",
            "include_timestamps=false",
            "include_language_detection=false",
        ].joined(separator: "&")

        guard let url = URL(string: "\(baseURL)?\(query)") else {
            updateUI("Invalid WebSocket URL.")
            return
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        webSocket = task
        task.resume()

        receiveMessages()
    }

    private func receiveMessages() {
        guard isListening, let webSocket else { return }
        webSocket.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.logError("WebSocket error: \(error.localizedDescription)")
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleMessageData(data)
                case .string(let text):
                    self.handleMessageText(text)
                @unknown default:
                    break
                }
            }
            self.receiveMessages()
        }
    }

    private func handleMessageData(_ data: Data) {
        if let text = String(data: data, encoding: .utf8) {
            handleMessageText(text)
        }
    }

    private func handleMessageText(_ text: String) {
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8), options: []),
              let dict = json as? [String: Any],
              let messageType = dict["message_type"] as? String else {
            return
        }

        switch messageType {
        case "session_started":
            isSessionReady = true
            updateUI(committedText.isEmpty ? "Listening..." : currentDisplayText())
        case "partial_transcript":
            partialText = dict["text"] as? String ?? ""
            updateUI(currentDisplayText())
        case "committed_transcript", "committed_transcript_with_timestamps":
            let text = dict["text"] as? String ?? ""
            if !text.isEmpty {
                let now = Date()
                let gap = lastCommitTime.map { now.timeIntervalSince($0) } ?? 0
                let prefix: String
                if committedText.isEmpty {
                    prefix = ""
                } else if gap >= AppConfig.pauseForBlankLine {
                    prefix = "\n"
                } else {
                    prefix = " "
                }

                committedText = (committedText + prefix + text).trimmingCharacters(in: .whitespacesAndNewlines)
                committedText = trimIfNeeded(committedText)
                lastCommitTime = now
            }
            partialText = ""
            updateUI(currentDisplayText())
        case "auth_error", "quota_exceeded", "transcriber_error", "input_error", "error":
            let errorText = dict["error"] as? String ?? "Unknown error"
            logError("Scribe error: \(errorText)")
            if messageType == "auth_error" {
                handleAuthError()
            }
        default:
            break
        }
    }

    private func currentDisplayText() -> String {
        let combined = (committedText + " " + partialText).trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "Listening..." : combined
    }

    private func trimIfNeeded(_ text: String) -> String {
        let limit = 2000
        if text.count <= limit { return text }
        let start = text.index(text.endIndex, offsetBy: -limit)
        return String(text[start...])
    }

    private func startAudioCapture() {
        guard systemAudioTap == nil else { return }
        guard #available(macOS 14.4, *) else {
            logError("System audio capture requires macOS 14.4 or newer.")
            updateUI("macOS 14.4+ required for system audio.")
            return
        }

        do {
            let tap = try SystemAudioTap()
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: targetSampleRate,
                channels: targetChannels,
                interleaved: true
            )!

            audioConverter = AVAudioConverter(from: tap.format, to: targetFormat)
            systemAudioTap = tap

            try tap.start(on: audioCaptureQueue) { [weak self] buffer in
                self?.processAudioBuffer(buffer, targetFormat: targetFormat)
            }
        } catch {
            logError("System audio capture error: \(error.localizedDescription)")
            updateUI("Unable to capture system audio.")
        }
    }

    private func stopAudioCapture() {
        systemAudioTap?.stop()
        systemAudioTap = nil
        audioConverter = nil
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let converter = audioConverter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
            return
        }

        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            logError("Audio convert error: \(error.localizedDescription)")
            return
        }

        guard let channelData = outputBuffer.int16ChannelData else { return }
        let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        let data = Data(bytes: channelData[0], count: byteCount)
        sendAudioData(data, sampleRate: Int(targetFormat.sampleRate))
    }

    private func sendAudioData(_ data: Data, sampleRate: Int) {
        guard isListening, isSessionReady, let webSocket else { return }
        let payload: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": data.base64EncodedString(),
            "sample_rate": sampleRate,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        sendQueue.async {
            webSocket.send(.string(jsonString)) { _ in }
        }
    }

    private func updateUI(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.notchView.setText(text)
        }
    }

    private func logError(_ message: String) {
        NSLog("[Transcription] %@", message)
    }

    private func handleAuthError() {
        guard !didShowAuthError else { return }
        didShowAuthError = true
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "There was an error. Is your token correct?"
            alert.informativeText = "Capture Layer will now quit. Please check your ElevenLabs API key."
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            EnvLoader.removeApiKey()
            NSApplication.shared.terminate(nil)
        }
    }

    func presentTokenPrompt(completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Enter ElevenLabs API Key"
            alert.informativeText = "This key is saved locally for Capture Layer."
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
            field.placeholderString = "ELEVENLABS_API_KEY"
            alert.accessoryView = field
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                completion(value.isEmpty ? nil : value)
            } else {
                completion(nil)
            }
        }
    }

    private func alertMissingTokenAndQuit() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Token Required"
            alert.informativeText = "Please set your ElevenLabs API key to use Capture Layer."
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }
}
