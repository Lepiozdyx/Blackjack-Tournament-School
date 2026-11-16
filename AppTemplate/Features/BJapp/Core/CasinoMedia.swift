import AVFoundation
import UIKit

@MainActor
final class CasinoMedia {
    enum Event: String, Sendable { case tap, deal, flip, chip, coins, win, lose, purchase }
    private let audio = CasinoAudio()
    private var interrupted = false
    private var preferences = Preferences()
    private var foreground = true
    private var interruptionObserver: NSObjectProtocol?

    init() {
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    self.interrupted = true
                    self.updateMusic()
                } else {
                    self.interrupted = !AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
                    self.updateMusic()
                }
            }
        }
    }

    func configure(preferences: Preferences, foreground: Bool) {
        self.preferences = preferences
        if foreground && !self.foreground { interrupted = false }
        self.foreground = foreground
        updateMusic()
    }
    private func updateMusic() {
        audio.configure(musicEnabled: preferences.music, effectsEnabled: preferences.effects,
                        playbackAllowed: foreground && !interrupted)
    }
    func play(_ event: Event, preferences: Preferences) {
        guard foreground && !interrupted else { return }
        if preferences.effects {
            audio.play(event)
        }
        guard preferences.haptics else { return }
        switch event {
        case .win, .purchase, .coins: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .lose: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .chip: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        default: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// All mutable state and AVFoundation calls are confined to queue, including
// prepareToPlay/play, which can activate the audio session implicitly.
private nonisolated final class CasinoAudio: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.app.BJapp.audio", qos: .userInitiated)
    private var music: AVAudioPlayer?
    private var effects: [CasinoMedia.Event: AVAudioPlayer] = [:]
    private var playbackAllowed = false
    private var effectsEnabled = true
    private var sessionActive = false

    func configure(musicEnabled: Bool, effectsEnabled: Bool, playbackAllowed: Bool) {
        queue.async { [self] in
            self.playbackAllowed = playbackAllowed
            self.effectsEnabled = effectsEnabled
            if !playbackAllowed || !effectsEnabled {
                for player in effects.values { player.stop() }
            }
            guard playbackAllowed else {
                music?.pause()
                if sessionActive {
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    sessionActive = false
                }
                return
            }
            guard musicEnabled else { music?.pause(); return }
            guard activateSession() else { return }
            if music == nil, let url = resource("ambient") {
                music = try? AVAudioPlayer(contentsOf: url)
                music?.numberOfLoops = -1
                music?.volume = 0.36
                music?.prepareToPlay()
            }
            if music?.isPlaying == false { music?.play() }
        }
    }

    func play(_ event: CasinoMedia.Event) {
        queue.async { [self] in
            guard playbackAllowed && effectsEnabled, activateSession() else { return }
            if effects[event] == nil, let url = resource(event.rawValue) {
                effects[event] = try? AVAudioPlayer(contentsOf: url)
                effects[event]?.volume = 0.52
                effects[event]?.prepareToPlay()
            }
            effects[event]?.currentTime = 0
            effects[event]?.play()
        }
    }

    private func activateSession() -> Bool {
        if sessionActive { return true }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            // This synchronous API also supports iOS 17 and runs off the main thread.
            try session.setActive(true)
            sessionActive = true
            return true
        } catch { return false }
    }

    private func resource(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav") ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Resources")
    }
}
