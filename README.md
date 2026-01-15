<div style="position: relative; padding-bottom: 64.63195691202873%; height: 0;"><iframe src="https://www.loom.com/embed/6ad520e4ef004ee69b66279734750089" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;"></iframe></div>

# CaptureLayer

CaptureLayer is a lightweight macOS menu‑bar app that transcribes what your computer plays. It listens to system output audio (not the microphone) and displays live text in a small notch‑style overlay.

Inspired by [Notchie](https://www.notchie.app/).

## Features
- Real‑time transcription for system audio.
- Minimal UI that stays out of the way.
- Simple token management from the menu bar.

## Requirements
- macOS 14.4+ (uses the new CoreAudio output tap API)
- ElevenLabs API key (for the realtime transcription service)

## Install
1. Download the installer DMG.
2. Drag **CaptureLayer.app** to **Applications**.
3. Launch the app from Applications.

## First Run
On first launch, CaptureLayer will prompt for your ElevenLabs API key.  
If the key is missing or invalid, the app will tell you and quit.  
macOS will also prompt for system audio capture permission.

## Token Management
Use the menu‑bar icon:
- **Remove Token** clears the stored key and quits the app.

On next launch, you’ll be asked to enter a new key.

## Usage
- Once running, CaptureLayer transcribes system audio and shows text in the overlay.
- Use the menu‑bar icon to hide/show the panel or quit.

## Permissions
- **System Audio**: required to capture output audio.

## Notes
- CaptureLayer listens to system output audio only (it does not use the microphone).
- The API key is stored locally using macOS user defaults.

## Run From Source (for developers)
```
swift run
```

## Troubleshooting
- **No text appears**: verify your API key is valid.
- **App quits with a token error**: remove the token and enter a new one.

## Build (for developers)
```
swift build -c release
```

## Build App Bundle (for developers)
```
./scripts/build_app.sh
```

## Package (for developers)
```
./scripts/build_installer.sh
```
