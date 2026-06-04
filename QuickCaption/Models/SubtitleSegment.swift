//
//  SubtitleSegment.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

import Foundation

struct SubtitleSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var start: Double
    var end: Double
    var text: String

    init(id: UUID = UUID(), start: Double, end: Double, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }
}
