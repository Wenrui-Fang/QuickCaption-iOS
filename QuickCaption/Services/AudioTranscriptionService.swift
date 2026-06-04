//
//  AudioTranscriptionService.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

import Foundation

protocol AudioTranscriptionService {
    var providerName: String { get }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult
}
