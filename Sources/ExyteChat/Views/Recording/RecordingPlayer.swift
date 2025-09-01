//
//  RecordingPlayer.swift
//
//
//  Created by Alexandra Afonasova on 21.06.2022.
//

@preconcurrency import Combine
@preconcurrency import AVFoundation

final actor RecordingPlayer: ObservableObject {

    @MainActor @Published var playing = false
    @MainActor @Published var duration: Double = 0.0
    @MainActor @Published var secondsLeft: Double = 0.0
    @MainActor @Published var progress: Double = 0.0

    @MainActor let didPlayTillEnd = PassthroughSubject<Void, Never>()

    private var recording: Recording? {
        didSet {
            internalPlaying = false
            Task { @MainActor in
                self.progress = 0
                if let r = await self.recording {
                    self.duration = r.duration
                    self.secondsLeft = r.duration
                } else {
                    self.duration = 0
                    self.secondsLeft = 0
                }
            }
        }
    }

    private var internalPlaying = false {
        didSet {
            Task { @MainActor in
                self.playing = await internalPlaying
            }
        }
    }

    private let audioSession = AVAudioSession()
    private var player: AVPlayer?
    private var timeObserver: Any?

    init() {
        // Don't set category here - set it only when playing
        // try? audioSession.setCategory(.playback)
        // try? audioSession.overrideOutputAudioPort(.speaker)
    }

    func play(_ recording: Recording) {
        print("RecordingPlayer: Attempting to play recording with URL: \(recording.url?.absoluteString ?? "nil")")
        setupPlayer(for: recording)
        // Note: setupPlayer will handle playing after setup is complete
    }

    func pause() {
        player?.pause()
        internalPlaying = false
        // Deactivate audio session when pausing
        try? audioSession.setActive(false)
    }

    func togglePlay(_ recording: Recording) {
        print("RecordingPlayer: Toggle play - current state: \(internalPlaying ? "playing" : "paused")")
        if self.recording?.url != recording.url {
            setupPlayer(for: recording)
            return // setupPlayer will handle the playing after setup is complete
        }
        Task {
            if internalPlaying {
                pause()
            } else {
                await play()
            }
        }
    }

    func seek(with recording: Recording, to progress: Double) {
        let goalTime = recording.duration * progress
        if self.recording == nil {
            setupPlayer(for: recording)
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await player?.seek(to: CMTime(seconds: goalTime, preferredTimescale: 10))
                if !internalPlaying { 
                    await play() 
                }
            }
            return
        }
        player?.seek(to: CMTime(seconds: goalTime, preferredTimescale: 10))
        if !internalPlaying {
            Task {
                await play()
            }
        }
    }

    func seek(to progress: Double) {
        if let recording {
            let goalTime = recording.duration * progress
            player?.seek(to: CMTime(seconds: goalTime, preferredTimescale: 10))
            if !internalPlaying { 
                Task {
                    await play() 
                }
            }
        }
    }

    func reset() {
        if internalPlaying { pause() }
        recording = nil
    }

    private func startPlayback() async {
        await play()
    }

    private func play() async {
        print("RecordingPlayer: play() called - current audio session category: \(audioSession.category)")
        
        do {
            // Configure audio session for playback
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            print("RecordingPlayer: Audio session configured successfully for playback")
        } catch {
            print("RecordingPlayer: Failed to configure audio session for playback: \(error)")
            return
        }
        
        guard let player = player else {
            print("RecordingPlayer: Player is nil")
            return
        }
        
        print("RecordingPlayer: About to call player.play() - current rate: \(player.rate)")
        player.play()
        internalPlaying = true
        NotificationCenter.default.post(name: .chatAudioIsPlaying, object: self)
        print("RecordingPlayer: Called player.play() - new rate: \(player.rate)")
        
        // Add a delay to check if player is actually playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Task { [weak self] in
                guard let self = self else { return }
                guard let player = await self.player else { return }
                print("RecordingPlayer: Player status after 0.1s - rate: \(player.rate), status: \(player.status.rawValue)")
                if player.rate == 0.0 {
                    print("RecordingPlayer: Player stopped unexpectedly, checking for errors...")
                    if let item = player.currentItem {
                        print("RecordingPlayer: Player item status: \(item.status.rawValue), duration: \(item.duration.seconds)")
                        if let error = item.error {
                            print("RecordingPlayer: Player item error: \(error)")
                        }
                    }
                }
            }
        }
        
        // Check again after 0.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task { [weak self] in
                guard let self = self else { return }
                guard let player = await self.player else { return }
                print("RecordingPlayer: Player status after 0.5s - rate: \(player.rate), status: \(player.status.rawValue)")
                if let item = player.currentItem {
                    print("RecordingPlayer: Player item status: \(item.status.rawValue), duration: \(item.duration.seconds)")
                }
            }
        }
    }

    private func setupPlayer(for recording: Recording) {
        guard let url = recording.url else { 
            print("RecordingPlayer: Recording URL is nil")
            return 
        }
        
        print("RecordingPlayer: Setting up player with URL: \(url.absoluteString)")
        
        // Check if it's a remote URL
        if url.scheme == "http" || url.scheme == "https" {
            print("RecordingPlayer: Remote URL detected, downloading to cache")
            Task { @MainActor in
                do {
                    let localURL = try await AudioCacheManager.getLocalURL(for: url.absoluteString)
                    await setupPlayerWithURL(localURL, recording: recording)
                } catch {
                    print("RecordingPlayer: Failed to download remote audio file: \(error)")
                }
            }
        } else {
            // Local file URL
            if !FileManager.default.fileExists(atPath: url.path) {
                print("RecordingPlayer: Recording file does not exist at path: \(url.path)")
                return
            }
            Task {
                await setupPlayerWithURL(url, recording: recording)
            }
        }
    }
    
    private func setupPlayerWithURL(_ url: URL, recording: Recording) async {
        self.recording = recording

        await MainActor.run {
            NotificationCenter.default.removeObserver(self)
        }
        timeObserver = nil
        player?.replaceCurrentItem(with: nil)

        // Validate file exists and has content
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("RecordingPlayer: Audio file does not exist at path: \(url.path)")
            return
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("RecordingPlayer: Audio file size: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("RecordingPlayer: Audio file is empty")
                return
            }
            
            // Check if file size is suspiciously small for audio
            if fileSize < 1024 {
                print("RecordingPlayer: Warning - Audio file is very small (\(fileSize) bytes)")
            }
        } catch {
            print("RecordingPlayer: Error checking file attributes: \(error)")
            return
        }

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        print("RecordingPlayer: Created player item for URL: \(url.absoluteString)")
        
        await MainActor.run {
            // Add observer for player item status changes
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: playerItem,
                queue: nil
            ) { notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("RecordingPlayer: Failed to play to end: \(error)")
                }
            }
            
            NotificationCenter.default.addObserver(forName: .chatAudioIsPlaying, object: nil, queue: nil) { notification in
                if let sender = notification.object as? RecordingPlayer {
                    Task { [weak self] in
                        if await sender.recording?.url == self?.recording?.url {
                            return
                        }
                        await self?.pause()
                    }
                }
            }

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: nil
            ) { _ in
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.setPlayingState(false)
                    await self.player?.seek(to: .zero)
                    await MainActor.run {
                        self.didPlayTillEnd.send()
                    }
                }
            }
        }

        // Wait for the player item to be ready with proper duration
        await waitForPlayerItemReady(playerItem: playerItem)
    }
    
    private func waitForPlayerItemReady(playerItem: AVPlayerItem) async {
        // Check every 0.1 seconds for up to 5 seconds
        for attempt in 1...50 {
            if playerItem.status == .readyToPlay && !playerItem.duration.seconds.isNaN && playerItem.duration.seconds > 0 {
                print("RecordingPlayer: Player item ready after \(attempt * 100)ms - duration: \(playerItem.duration.seconds)")
                await setupTimeObserver()
                // Start playing immediately after setup is complete
                if !self.internalPlaying {
                    await self.startPlayback()
                }
                return
            } else if playerItem.status == .failed {
                print("RecordingPlayer: Player item failed to load: \(String(describing: playerItem.error))")
                return
            }
            
            // Wait 100ms before next check
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        print("RecordingPlayer: Timeout waiting for player item to be ready")
    }
    
    private func setupTimeObserver() async {
        guard let player = self.player else { return }
        
        let timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 10),
            queue: DispatchQueue.main
        ) { [weak self] time in
            Task { [weak self] in
                guard let self = self else { return }
                guard let player = await self.player else { return }
                guard let item = player.currentItem else { return }
                guard !item.duration.seconds.isNaN else { 
                    print("RecordingPlayer: Item duration is NaN in time observer")
                    return 
                }
                print("RecordingPlayer: Time observer callback - time: \(time.seconds), duration: \(item.duration.seconds)")
                await self.updateProgress(item.duration, time)
            }
        }
        
        await self.setTimeObserver(timeObserver)
        print("RecordingPlayer: Time observer setup completed")
    }
    
    private func setTimeObserver(_ observer: Any) {
        self.timeObserver = observer
    }

    private func setPlayingState(_ isPlaying: Bool) {
        self.internalPlaying = isPlaying
    }

    private func updateProgress(_ itemDuration: CMTime, _ time: CMTime) async {
        let durationSeconds = itemDuration.seconds
        let currentSeconds = time.seconds
        
        guard !durationSeconds.isNaN && !currentSeconds.isNaN && durationSeconds > 0 else {
            print("RecordingPlayer: Invalid duration or time values")
            return
        }
        
        await MainActor.run {
            self.duration = durationSeconds
            self.progress = currentSeconds / durationSeconds
            self.secondsLeft = max(0, (durationSeconds - currentSeconds).rounded())
        }
        
        print("RecordingPlayer: Progress update - current: \(currentSeconds), duration: \(durationSeconds), secondsLeft: \(await MainActor.run { self.secondsLeft }))")
    }
}
