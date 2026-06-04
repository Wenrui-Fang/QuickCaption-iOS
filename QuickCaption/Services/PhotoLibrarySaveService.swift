//
//  PhotoLibrarySaveService.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

import Photos

enum PhotoLibrarySaveError: LocalizedError {
    case accessDenied
    case accessRestricted
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Photos permission is off. Allow QuickCaption to add videos to Photos in Settings."
        case .accessRestricted:
            "Photos access is restricted on this device."
        case .saveFailed:
            "Could not save the exported video to Photos."
        }
    }
}

struct PhotoLibrarySaveService {
    func saveVideoToPhotoLibrary(_ videoURL: URL) async throws {
        debugLog("[QuickCaption][Photos] request add-only authorization")
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        debugLog("[QuickCaption][Photos] authorization status=\(status.rawValue)")

        switch status {
        case .authorized, .limited:
            break
        case .denied:
            debugLog("[QuickCaption][Photos] failed: access denied")
            throw PhotoLibrarySaveError.accessDenied
        case .restricted:
            debugLog("[QuickCaption][Photos] failed: access restricted")
            throw PhotoLibrarySaveError.accessRestricted
        case .notDetermined:
            debugLog("[QuickCaption][Photos] failed: authorization not determined")
            throw PhotoLibrarySaveError.accessDenied
        @unknown default:
            debugLog("[QuickCaption][Photos] failed: unknown authorization status")
            throw PhotoLibrarySaveError.saveFailed
        }

        debugLog("[QuickCaption][Photos] begin save videoURL=\(videoURL.path)")
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
        debugLog("[QuickCaption][Photos] save completed")
    }
}
