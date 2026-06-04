# QuickCaption iOS

QuickCaption is a personal-use native iOS app for generating, editing, styling, and exporting burned-in subtitles for short videos.

The app is local-first for the current MVP: it does not use a backend, login, cloud storage, payment, or third-party transcription API. Video processing, audio extraction, transcription, subtitle preview, and export all happen on device.

## Current Features

- Select a short video from Photos.
- Copy the selected video into the app temporary directory.
- Preview the video with live subtitle overlay.
- Extract audio locally from the selected video.
- Transcribe audio with Apple Speech Framework.
- Generate subtitle segments with timestamps.
- Edit subtitle text.
- Adjust subtitle start/end times in 0.1 second steps.
- Delete subtitle rows before export.
- Choose subtitle styles:
  - Classic: white text on translucent black background
  - Clean: white text with shadow
  - Creator: bold white text with black outline and strong drop shadow
- Adjust subtitle font size with a slider.
- Burn subtitles into a new MP4.
- Save the exported video to Photos.
- Clean temporary output files after successful export.
- Show recoverable permission errors with an Open Settings action.

## Tech Stack

- SwiftUI for the app UI
- PhotosUI for video selection
- AVKit / AVPlayer for video preview
- AVFoundation for audio extraction and video export
- Speech Framework for Apple Speech transcription
- Core Image + CoreText for burned-in subtitle rendering
- Photos Framework for saving exported videos
- FileManager for temporary media cleanup

## Project Structure

```text
QuickCaption/
├── QuickCaptionApp.swift
├── ContentView.swift
├── Models/
│   ├── SubtitleSegment.swift
│   ├── SubtitleStylePreset.swift
│   └── TranscriptionResult.swift
├── Services/
│   ├── AudioExtractionService.swift
│   ├── AudioTranscriptionService.swift
│   ├── AppleSpeechTranscriptionService.swift
│   ├── PhotoLibrarySaveService.swift
│   ├── SubtitleGenerationService.swift
│   └── VideoExportService.swift
└── Utilities/
    └── DebugLogger.swift
```

## Requirements

- Xcode 17 or newer
- iOS device or simulator for most preview/export work
- Real iPhone recommended for Apple Speech transcription

Apple Speech local recognition may fail in the iOS Simulator. If transcription fails with recognizer initialization errors, run the app on a real device.

## Running Locally

1. Open `QuickCaption.xcodeproj` in Xcode.
2. Select the `QuickCaption` scheme.
3. Choose a real iPhone when testing transcription.
4. Build and run.
5. Select a short video from Photos.

## Permissions

The app currently uses:

- `NSSpeechRecognitionUsageDescription` for Apple Speech transcription.
- `NSPhotoLibraryAddUsageDescription` for saving exported videos to Photos.

The selected-video flow uses `PhotosPicker`, so the app does not require full photo library read permission for the current MVP.

## Current Limitations

- The MVP is optimized for short videos, currently 3 minutes or less.
- The default transcription locale is `zh-CN`.
- The UI is still prototype-level and focused on the end-to-end captioning workflow.
- No cloud project saving or persistent caption drafts yet.
- No third-party transcription provider is integrated yet.

## Future Direction

The transcription layer is behind `AudioTranscriptionService`, so Apple Speech can later be replaced or supplemented with OpenAI or another provider without rewriting the rest of the caption preview/export pipeline.

Potential next steps:

- Add stronger export preflight validation.
- Add tests for subtitle grouping and timing adjustment.
- Refactor the main UI state into a ViewModel once the MVP behavior stabilizes.
- Add language selection.
- Add optional draft persistence.

## Design Doc

See [QuickCaption Design Doc.docx](QuickCaption%20Design%20Doc.docx) for the current MVP design and implementation notes.
