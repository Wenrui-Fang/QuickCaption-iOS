//
//  TranscriptionResult.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

import Foundation

struct TranscriptionResult: Equatable {
    let text: String
    let segments: [TranscriptionSegment]
    let providerName: String
}

struct TranscriptionSegment: Identifiable, Equatable {
    let id = UUID()
    let start: TimeInterval
    let duration: TimeInterval
    let text: String
    let confidence: Float
}
