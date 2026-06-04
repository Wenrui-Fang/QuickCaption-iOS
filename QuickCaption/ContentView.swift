//
//  ContentView.swift
//  QuickCaption
//
//  Created by fangwenrui on 5/30/26.
//

import AVFoundation
import AVKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var selectedItem: PhotosPickerItem?
    @State private var player: AVPlayer?
    @State private var timeObserverPlayer: AVPlayer?
    @State private var timeObserverToken: Any?
    @State private var currentPlaybackTime = 0.0
    @State private var videoURL: URL?
    @State private var videoDuration = 0.0
    @State private var isLoadingVideo = false
    @State private var isTranscribing = false
    @State private var isExporting = false
    @State private var transcriptionResult: TranscriptionResult?
    @State private var generatedSubtitles: [SubtitleSegment] = []
    @State private var cachedMediaURLs: [URL] = []
    @State private var isShowingCaptionEditor = false
    @State private var isShowingCaptionStyleEditor = false
    @State private var selectedSubtitleStyle: SubtitleStylePreset = .classic
    @State private var subtitleFontSizeMultiplier = 1.0
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var canRecoverPermissionInSettings = false

    private let mockSubtitles = [
        SubtitleSegment(start: 0.5, end: 2.0, text: "这是第一句字幕"),
        SubtitleSegment(start: 2.0, end: 4.0, text: "字幕会根据播放时间自动切换"),
        SubtitleSegment(start: 4.0, end: 6.5, text: "下一步会把字幕导出到视频里")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    videoPreview

                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        Label(videoURL == nil ? "Select Video" : "Choose Another Video", systemImage: "video.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoadingVideo || isProcessing)

                    if videoURL != nil {
                        Button {
                            Task {
                                await transcribeCurrentVideo()
                            }
                        } label: {
                            Label("Generate Captions", systemImage: "text.quote")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)

                        if !generatedSubtitles.isEmpty {
                            Button {
                                isShowingCaptionEditor = true
                            } label: {
                                Label("Edit Captions", systemImage: "pencil")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isProcessing)
                        }

                        Button {
                            isShowingCaptionStyleEditor = true
                        } label: {
                            Label("Caption Style", systemImage: "textformat")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing)

                        Button {
                            Task {
                                await exportCurrentVideo()
                            }
                        } label: {
                            Label(generatedSubtitles.isEmpty ? "Export Mock Video" : "Export Captioned Video", systemImage: "square.and.arrow.down")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing)
                    }

                    if let processingMessage {
                        ProgressView(processingMessage)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }

                    if let successMessage {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !generatedSubtitles.isEmpty {
                        Text("\(generatedSubtitles.count) subtitle(s) ready for preview and export.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    errorMessageView

                    if let transcriptionResult {
                        DisclosureGroup("\(transcriptionResult.providerName) transcript") {
                            Text(transcriptionResult.text)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .navigationTitle("QuickCaption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if videoURL != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            resetToInitialState()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .disabled(isProcessing)
                        .accessibilityLabel("Close video")
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await loadVideo(from: newItem)
                }
            }
            .onDisappear {
                removeTimeObserver()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .background else { return }
                guard !isProcessing else { return }

                debugLog("[QuickCaption][UI] app entered background; reset and clearing temporary media cache")
                resetToInitialState()
            }
            .sheet(isPresented: $isShowingCaptionEditor) {
                captionEditor
            }
            .sheet(isPresented: $isShowingCaptionStyleEditor) {
                captionStyleEditor
            }
        }
    }

    private var captionStyleEditor: some View {
        NavigationStack {
            VStack(spacing: 18) {
                captionStylePreview
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                subtitleStyleControls
                    .padding(.horizontal, 20)

                Spacer()
            }
            .navigationTitle("Caption Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isShowingCaptionStyleEditor = false
                    }
                }
            }
        }
    }

    private var captionEditor: some View {
        NavigationStack {
            VStack(spacing: 0) {
                captionEditorPreview
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                DisclosureGroup("Caption Style") {
                    subtitleStyleControls
                        .padding(.top, 10)
                }
                .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                List {
                    ForEach($generatedSubtitles) { $subtitle in
                        let isActive = currentSubtitle?.id == subtitle.id

                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                seekToSubtitle(subtitle)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isActive ? "play.circle.fill" : "play.circle")
                                    Text("\(formattedTimestamp(subtitle.start)) - \(formattedTimestamp(subtitle.end))")
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isActive ? .blue : .secondary)

                            TextField("Caption", text: $subtitle.text, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)

                            HStack(spacing: 10) {
                                captionTimingControl(
                                    title: "Start",
                                    value: subtitle.start,
                                    decreaseAction: {
                                        adjustSubtitleTime(id: subtitle.id, boundary: .start, delta: -0.1)
                                    },
                                    increaseAction: {
                                        adjustSubtitleTime(id: subtitle.id, boundary: .start, delta: 0.1)
                                    }
                                )

                                captionTimingControl(
                                    title: "End",
                                    value: subtitle.end,
                                    decreaseAction: {
                                        adjustSubtitleTime(id: subtitle.id, boundary: .end, delta: -0.1)
                                    },
                                    increaseAction: {
                                        adjustSubtitleTime(id: subtitle.id, boundary: .end, delta: 0.1)
                                    }
                                )

                                Button(role: .destructive) {
                                    deleteSubtitle(id: subtitle.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isProcessing)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(isActive ? Color.blue.opacity(0.08) : Color.clear)
                    }
                }
            }
            .navigationTitle("Edit Captions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isShowingCaptionEditor = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var captionStylePreview: some View {
        if let player {
            ZStack(alignment: .bottom) {
                VideoPlayer(player: player)

                subtitleOverlayText(currentSubtitle?.text ?? "Caption style preview", isCompact: false)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var captionEditorPreview: some View {
        if let player {
            ZStack(alignment: .bottom) {
                VideoPlayer(player: player)

                if let subtitle = currentSubtitle {
                    subtitleOverlayText(subtitle.text, isCompact: true)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 22)
                }
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(maxHeight: 360)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var videoPreview: some View {
        if let player {
            GeometryReader { proxy in
                let previewHeight = min(proxy.size.width * 16.0 / 9.0, 620)
                let previewWidth = previewHeight * 9.0 / 16.0

                HStack {
                    Spacer(minLength: 0)

                    ZStack(alignment: .bottom) {
                        VideoPlayer(player: player)

                        if let subtitle = currentSubtitle {
                            subtitleOverlayText(subtitle.text, isCompact: false)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 28)
                        }
                    }
                    .frame(width: previewWidth, height: previewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Spacer(minLength: 0)
                }
            }
            .frame(height: 620)
            .onAppear {
                player.play()
            }
            .onDisappear {
                player.pause()
            }
        } else {
            ContentUnavailableView(
                "No Video Selected",
                systemImage: "video",
                description: Text("Choose a short video from Photos to preview it here.")
            )
            .frame(maxWidth: .infinity)
            .frame(height: 360)
        }
    }

    @MainActor
    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item else { return }
        debugLog("[QuickCaption][Picker] load selected video")

        isLoadingVideo = true
        errorMessage = nil
        canRecoverPermissionInSettings = false
        successMessage = nil
        transcriptionResult = nil
        generatedSubtitles = []
        isShowingCaptionEditor = false
        removeTimeObserver()
        player?.pause()
        player = nil
        videoURL = nil

        do {
            guard let localURL = try await item.loadTransferable(type: VideoPickerTransfer.self)?.url else {
                debugLog("[QuickCaption][Picker] failed: transferable returned nil")
                throw VideoLoadingError.unableToLoadVideo
            }

            debugLog("[QuickCaption][Picker] localURL=\(localURL.path)")
            videoDuration = try await validateVideoDuration(at: localURL)
            videoURL = localURL
            cachedMediaURLs.append(localURL)
            currentPlaybackTime = 0

            let newPlayer = AVPlayer(url: localURL)
            player = newPlayer
            addTimeObserver(to: newPlayer)
            debugLog("[QuickCaption][Picker] player ready")
        } catch {
            debugLog("[QuickCaption][Picker] failed error=\(error.localizedDescription)")
            presentError(error)
        }

        isLoadingVideo = false
    }

    @MainActor
    private func transcribeCurrentVideo() async {
        guard let videoURL else { return }
        debugLog("[QuickCaption][UI] transcribe tapped videoURL=\(videoURL.path)")

        isTranscribing = true
        errorMessage = nil
        canRecoverPermissionInSettings = false
        successMessage = nil
        transcriptionResult = nil

        do {
            let audioURL = try await AudioExtractionService().extractAudio(from: videoURL)
            cachedMediaURLs.append(audioURL)
            let transcriptionService: any AudioTranscriptionService = AppleSpeechTranscriptionService()
            let result = try await transcriptionService.transcribe(audioURL: audioURL)
            let subtitles = SubtitleGenerationService().makeSubtitles(from: result)

            transcriptionResult = result
            generatedSubtitles = subtitles
            successMessage = "Transcribed audio with \(result.segments.count) segment(s), generated \(subtitles.count) subtitle(s)."
            debugLog("[QuickCaption][UI] transcription completed provider=\(result.providerName) subtitleCount=\(subtitles.count)")
        } catch {
            debugLog("[QuickCaption][UI] transcription failed error=\(error.localizedDescription)")
            presentError(error)
        }

        isTranscribing = false
        debugLog("[QuickCaption][UI] transcription loading cleared")
    }

    @MainActor
    private func exportCurrentVideo() async {
        guard let videoURL else { return }
        debugLog("[QuickCaption][UI] export tapped videoURL=\(videoURL.path)")

        isExporting = true
        errorMessage = nil
        canRecoverPermissionInSettings = false
        successMessage = nil
        player?.pause()

        do {
            let outputURL = try await VideoExportService().exportVideoWithSubtitles(
                sourceURL: videoURL,
                subtitles: activeSubtitles,
                style: selectedSubtitleStyle,
                fontSizeMultiplier: subtitleFontSizeMultiplier
            )
            cachedMediaURLs.append(outputURL)
            try await PhotoLibrarySaveService().saveVideoToPhotoLibrary(outputURL)
            removeTemporaryMedia(at: outputURL)
            successMessage = generatedSubtitles.isEmpty ? "Exported mock subtitle video saved to Photos." : "Exported subtitle video saved to Photos."
            debugLog("[QuickCaption][UI] export flow completed")
        } catch {
            debugLog("[QuickCaption][UI] export flow failed error=\(error.localizedDescription)")
            presentError(error)
        }

        isExporting = false
        debugLog("[QuickCaption][UI] export loading cleared")
    }

    private var isProcessing: Bool {
        isTranscribing || isExporting
    }

    private var processingMessage: String? {
        if isLoadingVideo {
            "Loading video..."
        } else if isTranscribing {
            "Generating captions..."
        } else if isExporting {
            "Exporting video..."
        } else {
            nil
        }
    }

    private var currentSubtitle: SubtitleSegment? {
        activeSubtitles.first { segment in
            segment.start <= currentPlaybackTime && currentPlaybackTime < segment.end
        }
    }

    private var activeSubtitles: [SubtitleSegment] {
        generatedSubtitles.isEmpty ? mockSubtitles : generatedSubtitles
    }

    @MainActor
    private func resetToInitialState() {
        debugLog("[QuickCaption][UI] reset to initial state")

        player?.pause()
        removeTimeObserver()
        player = nil
        selectedItem = nil
        videoURL = nil
        videoDuration = 0
        currentPlaybackTime = 0
        transcriptionResult = nil
        generatedSubtitles = []
        isShowingCaptionEditor = false
        isShowingCaptionStyleEditor = false
        selectedSubtitleStyle = .classic
        subtitleFontSizeMultiplier = 1.0
        successMessage = nil
        errorMessage = nil
        canRecoverPermissionInSettings = false

        clearTemporaryMediaCache()
    }

    private var errorMessageView: some View {
        Group {
            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if canRecoverPermissionInSettings {
                        Button {
                            openAppSettings()
                        } label: {
                            Label("Open Settings", systemImage: "gearshape")
                                .font(.footnote.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        canRecoverPermissionInSettings = shouldShowSettingsRecovery(for: error)
    }

    private func shouldShowSettingsRecovery(for error: Error) -> Bool {
        switch error {
        case TranscriptionError.speechRecognitionDenied:
            return true
        case PhotoLibrarySaveError.accessDenied:
            return true
        default:
            return false
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func clearTemporaryMediaCache() {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        var urlsToRemove = Set(cachedMediaURLs)

        if let temporaryFiles = try? fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        ) {
            for url in temporaryFiles where isQuickCaptionTemporaryMedia(url) {
                urlsToRemove.insert(url)
            }
        }

        for url in urlsToRemove {
            removeTemporaryMedia(at: url)
        }

        cachedMediaURLs = []
    }

    private func removeTemporaryMedia(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            try FileManager.default.removeItem(at: url)
            cachedMediaURLs.removeAll { $0 == url }
            debugLog("[QuickCaption][Cache] removed \(url.path)")
        } catch {
            debugLog("[QuickCaption][Cache] failed to remove \(url.path) error=\(error.localizedDescription)")
        }
    }

    private func isQuickCaptionTemporaryMedia(_ url: URL) -> Bool {
        let filename = url.lastPathComponent

        return filename.hasPrefix("quickcaption-input-")
            || filename.hasPrefix("quickcaption-audio-")
            || filename.hasPrefix("quickcaption-output-")
    }

    private func formattedTimestamp(_ seconds: Double) -> String {
        let totalTenths = Int((seconds * 10).rounded())
        let minutes = totalTenths / 600
        let wholeSeconds = (totalTenths % 600) / 10
        let tenths = totalTenths % 10

        return "\(minutes):\(String(format: "%02d", wholeSeconds)).\(tenths)"
    }

    private func seekToSubtitle(_ subtitle: SubtitleSegment) {
        let time = CMTime(seconds: subtitle.start, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        currentPlaybackTime = subtitle.start
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        player?.play()
    }

    private func captionTimingControl(
        title: String,
        value: Double,
        decreaseAction: @escaping () -> Void,
        increaseAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Button(action: decreaseAction) {
                    Image(systemName: "minus")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.bordered)

                Text(formattedTimestamp(value))
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 48)

                Button(action: increaseAction) {
                    Image(systemName: "plus")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.bordered)
            }
        }
        .disabled(isProcessing)
    }

    private func adjustSubtitleTime(id: SubtitleSegment.ID, boundary: SubtitleBoundary, delta: Double) {
        guard let index = generatedSubtitles.firstIndex(where: { $0.id == id }) else { return }

        let minimumDuration = 0.2
        let previousEnd = index > generatedSubtitles.startIndex ? generatedSubtitles[index - 1].end : 0
        let nextStart = index < generatedSubtitles.index(before: generatedSubtitles.endIndex)
            ? generatedSubtitles[index + 1].start
            : max(videoDuration, generatedSubtitles[index].end)

        switch boundary {
        case .start:
            let upperBound = generatedSubtitles[index].end - minimumDuration
            generatedSubtitles[index].start = clamped(
                generatedSubtitles[index].start + delta,
                lowerBound: previousEnd,
                upperBound: upperBound
            )
            seekToSubtitle(generatedSubtitles[index])
        case .end:
            let lowerBound = generatedSubtitles[index].start + minimumDuration
            generatedSubtitles[index].end = clamped(
                generatedSubtitles[index].end + delta,
                lowerBound: lowerBound,
                upperBound: nextStart
            )
        }
    }

    private func deleteSubtitle(id: SubtitleSegment.ID) {
        generatedSubtitles.removeAll { $0.id == id }
    }

    private func clamped(_ value: Double, lowerBound: Double, upperBound: Double) -> Double {
        min(max(value, lowerBound), upperBound)
    }

    private var subtitleStyleControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Style")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Style", selection: $selectedSubtitleStyle) {
                    ForEach(SubtitleStylePreset.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Font Size")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int((subtitleFontSizeMultiplier * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $subtitleFontSizeMultiplier, in: 0.8...1.4, step: 0.05) {
                    Text("Font Size")
                } minimumValueLabel: {
                    Image(systemName: "textformat.size.smaller")
                } maximumValueLabel: {
                    Image(systemName: "textformat.size.larger")
                }
            }
        }
        .disabled(isProcessing)
    }

    private func subtitleOverlayText(_ text: String, isCompact: Bool) -> some View {
        let baseFontSize = (isCompact ? 17.0 : 20.0) * subtitleFontSizeMultiplier

        return Text(text)
            .font(.system(size: baseFontSize, weight: selectedSubtitleStyle.fontWeight))
            .foregroundStyle(selectedSubtitleStyle.textColor)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, isCompact ? 12 : 14)
            .padding(.vertical, isCompact ? 7 : 8)
            .background(
                selectedSubtitleStyle.backgroundColor.opacity(selectedSubtitleStyle.backgroundOpacity),
                in: RoundedRectangle(cornerRadius: selectedSubtitleStyle.cornerRadius)
            )
            .shadow(color: .black.opacity(0.85), radius: selectedSubtitleStyle.shadowRadius, x: 0, y: 1)
            .shadow(
                color: .black.opacity(selectedSubtitleStyle == .creator ? 0.95 : 0),
                radius: selectedSubtitleStyle == .creator ? 1 : 0,
                x: 0,
                y: 0
            )
            .shadow(
                color: .black.opacity(selectedSubtitleStyle == .creator ? 0.95 : 0),
                radius: selectedSubtitleStyle == .creator ? 1 : 0,
                x: 1,
                y: 1
            )
            .shadow(
                color: .black.opacity(selectedSubtitleStyle == .creator ? 0.95 : 0),
                radius: selectedSubtitleStyle == .creator ? 1 : 0,
                x: -1,
                y: -1
            )
    }

    private func validateVideoDuration(at url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        debugLog("[QuickCaption][Picker] video duration=\(duration)s")

        guard duration <= 180 else {
            throw VideoLoadingError.videoTooLong
        }

        return duration
    }

    private func addTimeObserver(to player: AVPlayer) {
        removeTimeObserver()

        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentPlaybackTime = time.seconds
        }
        timeObserverPlayer = player
    }

    private func removeTimeObserver() {
        guard let timeObserverToken else { return }

        timeObserverPlayer?.removeTimeObserver(timeObserverToken)
        self.timeObserverToken = nil
        timeObserverPlayer = nil
    }
}

private enum SubtitleBoundary {
    case start
    case end
}

private struct VideoPickerTransfer: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let fileExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("quickcaption-input-\(UUID().uuidString)")
                .appendingPathExtension(fileExtension)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: received.file, to: destinationURL)
            return VideoPickerTransfer(url: destinationURL)
        }
    }
}

private enum VideoLoadingError: LocalizedError {
    case unableToLoadVideo
    case videoTooLong

    var errorDescription: String? {
        switch self {
        case .unableToLoadVideo:
            "Could not load the selected video."
        case .videoTooLong:
            "Please choose a video shorter than 3 minutes."
        }
    }
}
