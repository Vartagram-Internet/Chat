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
            Task {
                await MainActor.run {
                    self.progress = 0
                }

                guard let r = await self.recording,
                      let url = r.url else {
                    await MainActor.run {
                        self.duration = 0
                        self.secondsLeft = 0
                    }
                    return
                }

                do {
                    let realDuration = try await Self.getDuration(of: url)
                    await MainActor.run {
                        self.duration = realDuration
                        self.secondsLeft = realDuration
                    }
                } catch {
                    print("⚠️ Failed to load duration from file: \(error)")
                    await MainActor.run {
                        self.duration = 0
                        self.secondsLeft = 0
                    }
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

    private let audioSession = AVAudioSession.sharedInstance()

    private var player: AVPlayer?
    private var timeObserver: Any?

    init() {
        do {
            try audioSession.setCategory(.playback)
            try audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    func play(_ recording: Recording) {
        setupPlayer(for: recording)
        Task {
            await playWhenReady()
        }
    }


    func pause() {
        player?.pause()
        internalPlaying = false
    }

    func togglePlay(_ recording: Recording) {
        if self.recording?.url != recording.url {
            setupPlayer(for: recording)
        }
        internalPlaying ? pause() : play()
    }

    func seek(with recording: Recording, to progress: Double) {
        let goalTime = recording.duration * progress
        if self.recording == nil {
            setupPlayer(for: recording)
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await player?.seek(to: CMTime(seconds: goalTime, preferredTimescale: 10))
                if !internalPlaying { play() }
            }
            return
        }
        player?.seek(to: CMTime(seconds: goalTime, preferredTimescale: 10))
        if !internalPlaying {
            play()
        }
    }

    func seek(to progress: Double) {
        if let recording {
            let goalTime = recording.duration * progress
            player?.seek(to: CMTime(seconds: goalTime, preferredTimescale: 10))
            if !internalPlaying { play() }
        }
    }

    func reset() {
        if internalPlaying { pause() }
        removeObservers()
        recording = nil
        timeObserver = nil
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func play() {
        do {
            try audioSession.setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
        player?.play()
        internalPlaying = true
        NotificationCenter.default.post(name: .chatAudioIsPlaying, object: self)
    }
    private func playWhenReady() async {
        do {
            try audioSession.setActive(true)
            await player?.play()
            internalPlaying = true
            NotificationCenter.default.post(name: .chatAudioIsPlaying, object: self)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }


    private func setupPlayer(for recording: Recording) {
        guard let url = recording.url else {
            print("⚠️ Recording URL is nil. Cannot setup player.")
            return
        }

        self.recording = recording

        removeObservers()

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        NotificationCenter.default.addObserver(forName: .chatAudioIsPlaying, object: nil, queue: nil) { [weak self] notification in
            guard let self else { return }
            if let sender = notification.object as? RecordingPlayer, sender.recording?.url != self.recording?.url {
                Task {
                    await self.pause()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: nil
        ) { [weak self] _ in
            Task {
                guard let self else { return }
                await self.setPlayingState(false)
                await self.player?.seek(to: .zero)
                await self.didPlayTillEnd.send()
            }
        }

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 10),
            queue: nil
        ) { [weak self] time in
            Task {
                guard let self, let item = await self.player?.currentItem, !item.duration.seconds.isNaN else { return }
                await MainActor.run {
                    self.updateProgress(item.duration, time)
                }
            }
        }
    }

    private func removeObservers() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func setPlayingState(_ isPlaying: Bool) async {
        self.internalPlaying = isPlaying
    }

    @MainActor
    private func updateProgress(_ itemDuration: CMTime, _ time: CMTime) {
        duration = itemDuration.seconds
        progress = time.seconds / itemDuration.seconds
        secondsLeft = (itemDuration - time).seconds.rounded()
    }

    static func getDuration(of url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
}
