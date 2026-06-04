//
//  SubtitleGenerationService.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

import Foundation

struct SubtitleGenerationService {
    func makeSubtitles(from transcription: TranscriptionResult) -> [SubtitleSegment] {
        let timedSegments = transcription.segments
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.start < $1.start }

        guard !timedSegments.isEmpty else {
            return []
        }

        var subtitles: [SubtitleSegment] = []
        var currentText = ""
        var currentStart = timedSegments[0].start
        var currentEnd = timedSegments[0].start + timedSegments[0].duration

        for segment in timedSegments {
            let segmentText = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let segmentStart = segment.start
            let segmentEnd = segment.start + max(segment.duration, 0.25)
            let candidateText = append(segmentText, to: currentText)
            let hasLongGap = segmentStart - currentEnd > 0.85
            let isTooLong = candidateText.count > 18
            let isTooSlow = segmentEnd - currentStart > 3.2

            if !currentText.isEmpty && (hasLongGap || isTooLong || isTooSlow) {
                subtitles.append(
                    SubtitleSegment(
                        start: currentStart,
                        end: max(currentEnd, currentStart + 0.8),
                        text: currentText
                    )
                )

                currentText = segmentText
                currentStart = segmentStart
                currentEnd = segmentEnd
            } else {
                currentText = candidateText
                currentEnd = max(currentEnd, segmentEnd)
            }
        }

        if !currentText.isEmpty {
            subtitles.append(
                SubtitleSegment(
                    start: currentStart,
                    end: max(currentEnd, currentStart + 0.8),
                    text: currentText
                )
            )
        }

        debugLog("[QuickCaption][Subtitles] generated subtitleCount=\(subtitles.count) from segmentCount=\(timedSegments.count)")
        return subtitles
    }

    private func append(_ text: String, to existingText: String) -> String {
        guard !existingText.isEmpty else {
            return text
        }

        if shouldInsertSpace(between: existingText, and: text) {
            return existingText + " " + text
        }

        return existingText + text
    }

    private func shouldInsertSpace(between lhs: String, and rhs: String) -> Bool {
        guard let left = lhs.last, let right = rhs.first else {
            return false
        }

        return isASCIILetterOrNumber(left) && isASCIILetterOrNumber(right)
    }

    private func isASCIILetterOrNumber(_ character: Character) -> Bool {
        guard character.isASCII, let scalar = character.unicodeScalars.first else {
            return false
        }

        return CharacterSet.alphanumerics.contains(scalar)
    }
}
