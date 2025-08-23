import Foundation
import AVFoundation
import CoreHaptics
import UIKit

@MainActor
final class AudioCue: ObservableObject {
    static let shared = AudioCue()
    
    private var audioPlayer: AVAudioPlayer?
    private var clapperPlayer: AVAudioPlayer?
    private var hornPlayer: AVAudioPlayer?
    private var bellPlayer: AVAudioPlayer?
    private var hapticEngine: CHHapticEngine?
    private var audioSession: AVAudioSession?
    
    @Published var isHapticsAvailable: Bool = false
    
    private init() {
        setupAudioSession()
        setupHaptics()
        preloadSounds()
    }
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession?.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession?.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            isHapticsAvailable = false
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            isHapticsAvailable = true
            
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                self?.isHapticsAvailable = false
            }
            
            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                do {
                    try self?.hapticEngine?.start()
                    self?.isHapticsAvailable = true
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
            isHapticsAvailable = false
        }
    }
    
    private func preloadSounds() {
        if let clapperURL = Bundle.main.url(forResource: "Clackers", withExtension: "wav") {
            do {
                clapperPlayer = try AVAudioPlayer(contentsOf: clapperURL)
                clapperPlayer?.prepareToPlay()
                clapperPlayer?.volume = 0.8
            } catch {
                print("Failed to load clapper sound: \(error)")
            }
        }
        
        if let hornURL = Bundle.main.url(forResource: "Horn", withExtension: "wav") {
            do {
                hornPlayer = try AVAudioPlayer(contentsOf: hornURL)
                hornPlayer?.prepareToPlay()
                hornPlayer?.volume = 1.0
            } catch {
                print("Failed to load horn sound: \(error)")
            }
        }
        
        if let bellURL = Bundle.main.url(forResource: "Bell", withExtension: "wav") {
            do {
                bellPlayer = try AVAudioPlayer(contentsOf: bellURL)
                bellPlayer?.prepareToPlay()
                bellPlayer?.volume = 0.8
            } catch {
                print("Failed to load bell sound: \(error)")
            }
        }
    }
    
    func playClapper() {
        clapperPlayer?.play()
        triggerHaptic(intensity: 0.8, sharpness: 0.7)
    }
    
    func playHorn() {
        hornPlayer?.play()
        triggerHaptic(intensity: 1.0, sharpness: 1.0, duration: 0.5)
    }
    
    func playBell() {
        bellPlayer?.play()
        triggerHaptic(intensity: 0.7, sharpness: 0.8, duration: 0.3)
    }
    
    func playPhaseTransition() {
        triggerHaptic(intensity: 0.6, sharpness: 0.5)
    }
    
    func playStartCountdown() {
        triggerHaptic(intensity: 0.4, sharpness: 0.8, duration: 0.1)
    }
    
    func triggerHaptic(intensity: Float = 0.5, sharpness: Float = 0.5, duration: TimeInterval = 0.2) {
        guard isHapticsAvailable, let hapticEngine = hapticEngine else {
            UIImpactFeedbackGenerator(style: intensity > 0.7 ? .heavy : .medium).impactOccurred()
            return
        }
        
        do {
            let hapticIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let hapticSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [hapticIntensity, hapticSharpness],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    func prepareForSession() {
        do {
            try audioSession?.setActive(true)
            try hapticEngine?.start()
        } catch {
            print("Failed to prepare audio/haptics for session: \(error)")
        }
    }
    
    func endSession() {
        do {
            try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
            hapticEngine?.stop()
        } catch {
            print("Failed to end audio/haptic session: \(error)")
        }
    }
}

@MainActor
final class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()
    
    private var audioSession: AVAudioSession
    private var wasPlayingBeforeInterruption = false
    
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((Bool) -> Void)?
    
    private init() {
        audioSession = AVAudioSession.sharedInstance()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            wasPlayingBeforeInterruption = true
            Task { @MainActor in
                onInterruptionBegan?()
            }
            
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                Task { @MainActor in
                    onInterruptionEnded?(false)
                }
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(AVAudioSession.InterruptionOptions.shouldResume)
            
            Task { @MainActor in
                onInterruptionEnded?(shouldResume && wasPlayingBeforeInterruption)
            }
            wasPlayingBeforeInterruption = false
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            Task { @MainActor in
                onInterruptionBegan?()
            }
        default:
            break
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}