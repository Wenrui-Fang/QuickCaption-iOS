//
//  AudioExtractionService.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

import AVFoundation

enum AudioExtractionError: LocalizedError {
    case missingAudioTrack
    case cannotCreateExportSession
    case unsupportedM4AExport

    var errorDescription: String? {
        switch self {
        case .missingAudioTrack:
            "Could not find an audio track in the selected video."
        case .cannotCreateExportSession:
            "Could not create the audio export session."
        case .unsupportedM4AExport:
            "This video's audio cannot be exported as M4A."
        }
    }
}

struct AudioExtractionService {
    func extractAudio(from sourceURL: URL) async throws -> URL {
        debugLog("[QuickCaption][Audio] start extraction sourceURL=\(sourceURL.path)")

        let asset = AVURLAsset(url: sourceURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard !audioTracks.isEmpty else {
            debugLog("[QuickCaption][Audio] failed: missing audio track")
            throw AudioExtractionError.missingAudioTrack
        }

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            debugLog("[QuickCaption][Audio] failed: could not create export session")
            throw AudioExtractionError.cannotCreateExportSession
        }

        guard exportSession.supportedFileTypes.contains(.m4a) else {
            debugLog("[QuickCaption][Audio] failed: M4A unsupported supportedFileTypes=\(exportSession.supportedFileTypes)")
            throw AudioExtractionError.unsupportedM4AExport
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quickcaption-audio-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        debugLog("[QuickCaption][Audio] outputURL=\(outputURL.path)")
        debugLog("[QuickCaption][Audio] supportedFileTypes=\(exportSession.supportedFileTypes)")
        debugLog("[QuickCaption][Audio] begin export")

        try await exportSession.export(to: outputURL, as: .m4a)

        let fileSize = try? FileManager.default
            .attributesOfItem(atPath: outputURL.path)[.size] as? Int64
        debugLog("[QuickCaption][Audio] finished export outputExists=\(FileManager.default.fileExists(atPath: outputURL.path)) fileSize=\(fileSize ?? 0)")

        return outputURL
    }
}
