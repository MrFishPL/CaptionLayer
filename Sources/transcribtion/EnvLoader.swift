import Foundation

enum EnvLoader {
    static func loadApiKey() -> String? {
        if let value = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !value.isEmpty {
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
            if parts.count == 2 && parts[0] == "ELEVENLABS_API_KEY" {
                return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }
}
