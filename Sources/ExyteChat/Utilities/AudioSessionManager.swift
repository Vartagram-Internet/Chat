//
//  AudioSessionManager.swift
//  
//
//  Created by Assistant on Audio Fix.
//

import Foundation
import AVFoundation

@MainActor
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    private init() {}
    
    func configureForRecording() throws {
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)
    }
    
    func configureForPlayback() throws {
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        try audioSession.overrideOutputAudioPort(.speaker)
    }
    
    func deactivate() throws {
        try audioSession.setActive(false)
    }
}
