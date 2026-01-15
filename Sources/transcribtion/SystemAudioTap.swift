import AudioToolbox
import AVFoundation
import Foundation

@available(macOS 14.4, *)
final class SystemAudioTap {
    private var tapID: AudioObjectID
    private var aggregateDeviceID: AudioObjectID = .unknown
    private var deviceProcID: AudioDeviceIOProcID?
    private let streamFormat: AVAudioFormat

    init() throws {
        let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = .unmuted

        var newTapID: AudioObjectID = .unknown
        var err = AudioHardwareCreateProcessTap(tapDescription, &newTapID)
        guard err == noErr else {
            throw SystemAudioTapError.tapCreationFailed(err)
        }
        tapID = newTapID

        var streamDescription = try tapID.readAudioTapStreamBasicDescription()
        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw SystemAudioTapError.invalidStreamFormat
        }
        streamFormat = format

        let systemOutputID = try AudioObjectID.readDefaultSystemOutputDevice()
        let outputUID = try systemOutputID.readDeviceUID()

        let aggregateUID = UUID().uuidString
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "CaptureLayer Output Tap",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: tapDescription.uuid.uuidString
                ]
            ]
        ]

        err = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateDeviceID)
        guard err == noErr else {
            throw SystemAudioTapError.aggregateCreationFailed(err)
        }
    }

    var format: AVAudioFormat {
        streamFormat
    }

    func start(on queue: DispatchQueue, handler: @escaping (AVAudioPCMBuffer) -> Void) throws {
        var err = AudioDeviceCreateIOProcIDWithBlock(&deviceProcID, aggregateDeviceID, queue) { [weak self] _, inInputData, _, _, _ in
            guard let self else { return }
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: self.streamFormat,
                bufferListNoCopy: inInputData,
                deallocator: nil
            ) else { return }
            handler(buffer)
        }
        guard err == noErr else {
            throw SystemAudioTapError.ioProcCreationFailed(err)
        }

        err = AudioDeviceStart(aggregateDeviceID, deviceProcID)
        guard err == noErr else {
            throw SystemAudioTapError.deviceStartFailed(err)
        }
    }

    func stop() {
        if aggregateDeviceID.isValid {
            let err = AudioDeviceStop(aggregateDeviceID, deviceProcID)
            if err != noErr {
                NSLog("[SystemAudioTap] Failed to stop aggregate device: %d", err)
            }

            if let deviceProcID {
                let destroyErr = AudioDeviceDestroyIOProcID(aggregateDeviceID, deviceProcID)
                if destroyErr != noErr {
                    NSLog("[SystemAudioTap] Failed to destroy IO proc: %d", destroyErr)
                }
                self.deviceProcID = nil
            }

            let destroyErr = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            if destroyErr != noErr {
                NSLog("[SystemAudioTap] Failed to destroy aggregate device: %d", destroyErr)
            }
            aggregateDeviceID = .unknown
        }

        if tapID.isValid {
            let err = AudioHardwareDestroyProcessTap(tapID)
            if err != noErr {
                NSLog("[SystemAudioTap] Failed to destroy process tap: %d", err)
            }
            tapID = .unknown
        }
    }

    deinit {
        stop()
    }
}

@available(macOS 14.4, *)
private enum SystemAudioTapError: LocalizedError {
    case tapCreationFailed(OSStatus)
    case aggregateCreationFailed(OSStatus)
    case deviceStartFailed(OSStatus)
    case ioProcCreationFailed(OSStatus)
    case invalidStreamFormat

    var errorDescription: String? {
        switch self {
        case .tapCreationFailed(let status):
            return "Process tap creation failed: \(status)"
        case .aggregateCreationFailed(let status):
            return "Aggregate device creation failed: \(status)"
        case .deviceStartFailed(let status):
            return "Aggregate device start failed: \(status)"
        case .ioProcCreationFailed(let status):
            return "Aggregate device IO proc creation failed: \(status)"
        case .invalidStreamFormat:
            return "Invalid tap stream format."
        }
    }
}
