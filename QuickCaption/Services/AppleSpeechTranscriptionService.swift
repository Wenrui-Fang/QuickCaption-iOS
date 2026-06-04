//
//  AppleSpeechTranscriptionService.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

import Foundation
import Speech

enum TranscriptionError: LocalizedError {
    case speechRecognitionDenied
    case speechRecognitionRestricted
    case speechRecognitionUnavailable
    case unsupportedLocale
    case emptyResult
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .speechRecognitionDenied:
            "Speech Recognition permission is off. Allow QuickCaption to use Speech Recognition in Settings."
        case .speechRecognitionRestricted:
            "Speech recognition is restricted on this device."
        case .speechRecognitionUnavailable:
            "Speech recognition is currently unavailable."
        case .unsupportedLocale:
            "Speech recognition is not available for the selected language."
        case .emptyResult:
            "Speech recognition finished without text."
        case .recognitionFailed(let reason):
            "Speech recognition failed: \(reason)"
        }
    }
}

struct AppleSpeechTranscriptionService: AudioTranscriptionService {
    let providerName = "Apple Speech"

    private let locale: Locale

    init(locale: Locale = Locale(identifier: "zh-CN")) {
        self.locale = locale
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        debugLog("[QuickCaption][Transcription][AppleSpeech] start audioURL=\(audioURL.path) locale=\(locale.identifier)")

        try await requestSpeechAuthorization()

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            debugLog("[QuickCaption][Transcription][AppleSpeech] failed: unsupported locale")
            throw TranscriptionError.unsupportedLocale
        }

        guard recognizer.isAvailable else {
            debugLog("[QuickCaption][Transcription][AppleSpeech] failed: recognizer unavailable")
            throw TranscriptionError.speechRecognitionUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = false
        request.addsPunctuation = true

        let speechResult = try await runRecognition(request: request, recognizer: recognizer)
        let transcription = speechResult.bestTranscription
        let text = transcription.formattedString

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            debugLog("[QuickCaption][Transcription][AppleSpeech] failed: empty result")
            throw TranscriptionError.emptyResult
        }

        let segments = transcription.segments.map { segment in
            TranscriptionSegment(
                start: segment.timestamp,
                duration: segment.duration,
                text: segment.substring,
                confidence: segment.confidence
            )
        }

        debugLog("[QuickCaption][Transcription][AppleSpeech] finished textLength=\(text.count) segmentCount=\(segments.count)")

        return TranscriptionResult(
            text: text,
            segments: segments,
            providerName: providerName
        )
    }

    private func requestSpeechAuthorization() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        debugLog("[QuickCaption][Transcription][AppleSpeech] authorization status=\(status.rawValue)")

        switch status {
        case .authorized:
            return
        case .denied:
            throw TranscriptionError.speechRecognitionDenied
        case .restricted:
            throw TranscriptionError.speechRecognitionRestricted
        case .notDetermined:
            throw TranscriptionError.speechRecognitionUnavailable
        @unknown default:
            throw TranscriptionError.speechRecognitionUnavailable
        }
    }

    private func runRecognition(
        request: SFSpeechURLRecognitionRequest,
        recognizer: SFSpeechRecognizer
    ) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            var recognitionTask: SFSpeechRecognitionTask?

            func resumeOnce(with result: Result<SFSpeechRecognitionResult, Error>) {
                guard !didResume else { return }
                didResume = true

                switch result {
                case .success(let speechResult):
                    continuation.resume(returning: speechResult)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }

                recognitionTask?.cancel()
                recognitionTask = nil
            }

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    let nsError = error as NSError
                    debugLog("[QuickCaption][Transcription][AppleSpeech] recognition failed domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription) userInfo=\(nsError.userInfo)")
                    resumeOnce(with: .failure(TranscriptionError.recognitionFailed(userFacingReason(for: nsError))))
                    return
                }

                guard let result else { return }

                if result.isFinal {
                    resumeOnce(with: .success(result))
                }
            }
        }
    }

    private func userFacingReason(for error: NSError) -> String {
        if error.localizedDescription == "Failed to initialize recognizer" {
            return "Apple Speech could not initialize the recognizer. This often happens in the iOS Simulator; try the same video on a real device."
        }

        return error.localizedDescription
    }
}
