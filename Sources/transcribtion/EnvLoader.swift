import Foundation

enum EnvLoader {
    static func loadApiKey() -> String? {
        if let value = loadValue(for: "ELEVENLABS_API_KEY") { return value }
        return nil
    }

    static func loadAudioDeviceName() -> String? {
        return loadValue(for: "AUDIO_INPUT_DEVICE")
    }

    private static func loadValue(for key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }

        let envURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".env")

        guard let data = try? Data(contentsOf: envURL),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 && parts[0] == key {
                return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }
}
