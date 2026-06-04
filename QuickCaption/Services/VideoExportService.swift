//
//  VideoExportService.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

import AVFoundation
import CoreImage
import CoreText

enum VideoExportError: LocalizedError {
    case missingVideoTrack
    case cannotCreateExportSession
    case exportFailed
    case unsupportedMP4Export

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            "Could not find a video track in the selected file."
        case .cannotCreateExportSession:
            "Could not create the video export session."
        case .exportFailed:
            "Video export failed."
        case .unsupportedMP4Export:
            "This video cannot be exported as MP4."
        }
    }
}

struct VideoExportService {
    func exportVideoWithSubtitles(
        sourceURL: URL,
        subtitles: [SubtitleSegment],
        style: SubtitleStylePreset = .classic,
        fontSizeMultiplier: Double = 1.0
    ) async throws -> URL {
        debugLog("[QuickCaption][Export] start Core Image export sourceURL=\(sourceURL.path)")

        let asset = AVURLAsset(url: sourceURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            debugLog("[QuickCaption][Export] failed: missing video track")
            throw VideoExportError.missingVideoTrack
        }

        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let renderSize = renderSize(for: naturalSize, transform: preferredTransform)
        debugLog("[QuickCaption][Export] duration=\(duration.seconds)s subtitleCount=\(subtitles.count)")
        debugLog("[QuickCaption][Export] naturalSize=\(naturalSize) renderSize=\(renderSize) transform=\(preferredTransform)")

        let videoComposition = try await makeCoreImageVideoComposition(
            asset: asset,
            subtitles: subtitles,
            style: style,
            fontSizeMultiplier: fontSizeMultiplier
        )
        debugLog("[QuickCaption][Export] configured Core Image video composition")

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quickcaption-output-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        debugLog("[QuickCaption][Export] outputURL=\(outputURL.path)")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            debugLog("[QuickCaption][Export] failed: could not create export session")
            throw VideoExportError.cannotCreateExportSession
        }

        guard exportSession.supportedFileTypes.contains(.mp4) else {
            debugLog("[QuickCaption][Export] failed: MP4 unsupported supportedFileTypes=\(exportSession.supportedFileTypes)")
            throw VideoExportError.unsupportedMP4Export
        }

        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        debugLog("[QuickCaption][Export] supportedFileTypes=\(exportSession.supportedFileTypes)")
        debugLog("[QuickCaption][Export] begin Core Image export")

        try await exportSession.export(to: outputURL, as: .mp4)
        debugLog("[QuickCaption][Export] finished Core Image export outputExists=\(FileManager.default.fileExists(atPath: outputURL.path))")

        return outputURL
    }

    private func makeCoreImageVideoComposition(
        asset: AVAsset,
        subtitles: [SubtitleSegment],
        style: SubtitleStylePreset,
        fontSizeMultiplier: Double
    ) async throws -> AVVideoComposition {
        try await AVVideoComposition(applyingFiltersTo: asset) { request in
            let sourceImage = request.sourceImage.clampedToExtent()
            let currentTime = request.compositionTime.seconds

            guard let subtitle = subtitles.first(where: { $0.start <= currentTime && currentTime < $0.end }) else {
                return AVCIImageFilteringResult(
                    resultImage: sourceImage.cropped(to: request.sourceImage.extent),
                    ciContext: nil
                )
            }

            let overlay = Self.makeSubtitleOverlayImage(
                text: subtitle.text,
                renderSize: request.sourceImage.extent.size,
                style: style,
                fontSizeMultiplier: fontSizeMultiplier
            )
            let outputImage = overlay
                .composited(over: sourceImage)
                .cropped(to: request.sourceImage.extent)

            return AVCIImageFilteringResult(resultImage: outputImage, ciContext: nil)
        }
    }

    private func renderSize(for naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let transformedSize = naturalSize.applying(transform)

        return CGSize(
            width: abs(transformedSize.width),
            height: abs(transformedSize.height)
        )
    }

    nonisolated private static func makeSubtitleOverlayImage(
        text: String,
        renderSize: CGSize,
        style: SubtitleStylePreset,
        fontSizeMultiplier: Double
    ) -> CIImage {
        let width = max(1, Int(renderSize.width.rounded()))
        let height = max(1, Int(renderSize.height.rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return CIImage.empty()
        }

        let canvasRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(canvasRect)

        let fontSize = max(34, renderSize.width * style.relativeFontScale * fontSizeMultiplier)
        let font = CTFontCreateWithName(style.exportFontName as CFString, fontSize, nil)
        let paragraphStyle = centeredParagraphStyle()
        let attributes: [NSAttributedString.Key: Any] = [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: style.exportTextColor,
            kCTParagraphStyleAttributeName as NSAttributedString.Key: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

        let horizontalMargin = renderSize.width * 0.08
        let textBoxWidth = renderSize.width - horizontalMargin * 2
        let maxTextBoxHeight = renderSize.height * 0.18
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: attributedString.length),
            nil,
            CGSize(width: textBoxWidth, height: maxTextBoxHeight),
            nil
        )

        let textBoxHeight = max(fontSize * 1.45, ceil(suggestedSize.height) + fontSize * 0.45)
        let bottomMargin = renderSize.height * 0.08
        let backgroundRect = CGRect(
            x: horizontalMargin - 18,
            y: bottomMargin - 12,
            width: textBoxWidth + 36,
            height: textBoxHeight + 24
        )

        context.setFillColor(style.exportBackgroundColor)
        context.addPath(CGPath(
            roundedRect: backgroundRect,
            cornerWidth: style.exportCornerRadius,
            cornerHeight: style.exportCornerRadius,
            transform: nil
        ))
        context.fillPath()

        let textRect = CGRect(
            x: horizontalMargin,
            y: bottomMargin + 10,
            width: textBoxWidth,
            height: textBoxHeight
        )
        let path = CGMutablePath()
        path.addRect(textRect)

        if style == .creator {
            let outlineOffset = max(2, fontSize * 0.038)
            let dropShadowOffset = max(8, fontSize * 0.18)
            let outlineAttributes: [NSAttributedString.Key: Any] = [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0.0, alpha: 0.95),
                kCTParagraphStyleAttributeName as NSAttributedString.Key: paragraphStyle
            ]
            let dropShadowAttributes: [NSAttributedString.Key: Any] = [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0.0, alpha: 0.82),
                kCTParagraphStyleAttributeName as NSAttributedString.Key: paragraphStyle
            ]
            let outlineString = NSAttributedString(string: text, attributes: outlineAttributes)
            let dropShadowString = NSAttributedString(string: text, attributes: dropShadowAttributes)

            let dropShadowOffsets = [
                CGPoint(x: 0, y: -dropShadowOffset * 0.75),
                CGPoint(x: dropShadowOffset * 0.15, y: -dropShadowOffset),
                CGPoint(x: dropShadowOffset * 0.3, y: -dropShadowOffset * 1.25),
                CGPoint(x: dropShadowOffset * 0.45, y: -dropShadowOffset * 1.5),
                CGPoint(x: dropShadowOffset * 0.55, y: -dropShadowOffset * 1.75)
            ]
            for offset in dropShadowOffsets {
                drawText(
                    dropShadowString,
                    in: textRect.offsetBy(dx: offset.x, dy: offset.y),
                    context: context
                )
            }

            let outlineOffsets = [
                CGPoint(x: -outlineOffset, y: 0),
                CGPoint(x: outlineOffset, y: 0),
                CGPoint(x: 0, y: -outlineOffset),
                CGPoint(x: 0, y: outlineOffset),
                CGPoint(x: -outlineOffset * 0.7, y: -outlineOffset * 0.7),
                CGPoint(x: outlineOffset * 0.7, y: -outlineOffset * 0.7),
                CGPoint(x: -outlineOffset * 0.7, y: outlineOffset * 0.7),
                CGPoint(x: outlineOffset * 0.7, y: outlineOffset * 0.7)
            ]

            for offset in outlineOffsets {
                drawText(
                    outlineString,
                    in: textRect.offsetBy(dx: offset.x, dy: offset.y),
                    context: context
                )
            }
        }

        drawText(attributedString, in: textRect, context: context)

        guard let cgImage = context.makeImage() else {
            return CIImage.empty()
        }

        return CIImage(cgImage: cgImage)
    }

    nonisolated private static func drawText(
        _ attributedString: NSAttributedString,
        in rect: CGRect,
        context: CGContext
    ) {
        let path = CGMutablePath()
        path.addRect(rect)

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributedString.length),
            path,
            nil
        )
        CTFrameDraw(frame, context)
    }

    nonisolated private static func centeredParagraphStyle() -> CTParagraphStyle {
        var alignment = CTTextAlignment.center
        var lineBreakMode = CTLineBreakMode.byWordWrapping

        return withUnsafePointer(to: &alignment) { alignmentPointer in
            withUnsafePointer(to: &lineBreakMode) { lineBreakModePointer in
                let settings = [
                    CTParagraphStyleSetting(
                        spec: .alignment,
                        valueSize: MemoryLayout<CTTextAlignment>.size,
                        value: alignmentPointer
                    ),
                    CTParagraphStyleSetting(
                        spec: .lineBreakMode,
                        valueSize: MemoryLayout<CTLineBreakMode>.size,
                        value: lineBreakModePointer
                    )
                ]

                return CTParagraphStyleCreate(settings, settings.count)
            }
        }
    }
}
