//
//  QuickCaptionApp.swift
//  QuickCaption
//
//  Created by fangwenrui on 5/30/26.
//

import AVFoundation
import SwiftUI

@main
struct QuickCaptionApp: App {
    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
            debugLog("[QuickCaption][AudioSession] configured playback session")
        } catch {
            debugLog("[QuickCaption][AudioSession] failed error=\(error.localizedDescription)")
        }
    }
}
