[in progress, real system-audio capturing will be added soon]

# CaptureLayer

CaptureLayer is a lightweight macOS menu‑bar app that transcribes what your computer plays. It listens to system output audio (not the microphone) and displays live text in a small notch‑style overlay.

## Features
- Real‑time transcription for system audio.
- Minimal UI that stays out of the way.
- Simple token management from the menu bar.

## Requirements
- macOS 13+
- ElevenLabs API key (for the realtime transcription service)

## Install
1. Download the installer DMG.
2. Drag **CaptureLayer.app** to **Applications**.
3. Launch the app from Applications.

## First Run
On first launch, CaptureLayer will prompt for your ElevenLabs API key.  
If the key is missing or invalid, the app will tell you and quit.

## Token Management
Use the menu‑bar icon:
- **Remove Token** clears the stored key and quits the app.

On next launch, you’ll be asked to enter a new key.

## Usage
- Once running, CaptureLayer transcribes system audio and shows text in the overlay.
- Use the menu‑bar icon to hide/show the panel or quit.

## Notes
- CaptureLayer listens to system output audio only (it does not use the microphone).
- The API key is stored locally using macOS user defaults.

## Troubleshooting
- **No text appears**: verify your API key is valid.
- **App quits with a token error**: remove the token and enter a new one.

## Build (for developers)
```
swift build -c release
```

## Package (for developers)
```
./scripts/build_installer.sh
```
