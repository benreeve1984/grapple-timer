import Foundation
import Combine

enum Phase: Equatable {
    case idle
    case starting(countdown: Int)
    case work(round: Int, totalRounds: Int)
    case rest(round: Int, totalRounds: Int)
    case done
    
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .starting: return "Get Ready"
        case .work: return "WORK"
        case .rest: return "REST"
        case .done: return "DONE"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .work, .rest, .starting:
            return true
        default:
            return false
        }
    }
}

struct TimerConfiguration: Codable, Equatable {
    var roundDuration: TimeInterval
    var restDuration: TimeInterval
    var rounds: Int
    var clapperTime: TimeInterval
    var startDelay: TimeInterval
    
    static let `default` = TimerConfiguration(
        roundDuration: 300,
        restDuration: 60,
        rounds: 5,
        clapperTime: 10,
        startDelay: 0
    )
    
    var isValid: Bool {
        roundDuration > 0 &&
        restDuration > 0 &&
        rounds > 0 &&
        clapperTime >= 0 &&
        clapperTime < roundDuration &&
        startDelay >= 0
    }
}

struct TimerSession: Equatable {
    let configuration: TimerConfiguration
    let startTime: Date
    var pausedAt: Date?
    var accumulatedPauseTime: TimeInterval = 0
    
    var totalDuration: TimeInterval {
        let workTime = configuration.roundDuration * Double(configuration.rounds)
        let restTime = configuration.restDuration * Double(configuration.rounds - 1)
        return configuration.startDelay + workTime + restTime
    }
    
    func elapsedTime(at date: Date = Date()) -> TimeInterval {
        guard pausedAt == nil else {
            return startTime.distance(to: pausedAt!) - accumulatedPauseTime
        }
        return startTime.distance(to: date) - accumulatedPauseTime
    }
    
    func currentPhase(at date: Date = Date()) -> Phase {
        let elapsed = elapsedTime(at: date)
        
        if elapsed < 0 {
            return .idle
        }
        
        if elapsed < configuration.startDelay {
            let remaining = Int(ceil(configuration.startDelay - elapsed))
            return .starting(countdown: remaining)
        }
        
        let adjustedElapsed = elapsed - configuration.startDelay
        
        if adjustedElapsed >= totalDuration - configuration.startDelay {
            return .done
        }
        
        let cycleTime = configuration.roundDuration + configuration.restDuration
        
        for round in 1...configuration.rounds {
            let cycleStart = Double(round - 1) * cycleTime
            let workEnd = cycleStart + configuration.roundDuration
            let restEnd = cycleStart + cycleTime
            
            if adjustedElapsed < workEnd {
                return .work(round: round, totalRounds: configuration.rounds)
            } else if round < configuration.rounds && adjustedElapsed < restEnd {
                return .rest(round: round, totalRounds: configuration.rounds)
            }
        }
        
        return .done
    }
    
    func timeRemaining(in phase: Phase, at date: Date = Date()) -> TimeInterval {
        let elapsed = elapsedTime(at: date)
        
        switch phase {
        case .starting(let countdown):
            return max(0, Double(countdown))
            
        case .work(let round, _):
            let adjustedElapsed = elapsed - configuration.startDelay
            let cycleStart = Double(round - 1) * (configuration.roundDuration + configuration.restDuration)
            let workEnd = cycleStart + configuration.roundDuration
            return max(0, workEnd - adjustedElapsed)
            
        case .rest(let round, _):
            let adjustedElapsed = elapsed - configuration.startDelay
            let cycleStart = Double(round - 1) * (configuration.roundDuration + configuration.restDuration)
            let restEnd = cycleStart + configuration.roundDuration + configuration.restDuration
            return max(0, restEnd - adjustedElapsed)
            
        default:
            return 0
        }
    }
    
    func shouldTriggerClapper(at date: Date = Date()) -> Bool {
        guard case .work = currentPhase(at: date) else { return false }
        let remaining = timeRemaining(in: currentPhase(at: date), at: date)
        return abs(remaining - configuration.clapperTime) < 0.5
    }
    
    func nextPhase(after phase: Phase) -> Phase? {
        switch phase {
        case .idle:
            return configuration.startDelay > 0 ? .starting(countdown: Int(configuration.startDelay)) : .work(round: 1, totalRounds: configuration.rounds)
        case .starting:
            return .work(round: 1, totalRounds: configuration.rounds)
        case .work(let round, let total):
            if round < total {
                return .rest(round: round, totalRounds: total)
            } else {
                return .done
            }
        case .rest(let round, let total):
            if round < total {
                return .work(round: round + 1, totalRounds: total)
            } else {
                return .done
            }
        case .done:
            return nil
        }
    }
}

@MainActor
final class TimerEngine: ObservableObject {
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var session: TimerSession?
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var isPaused: Bool = false
    
    private var timer: Timer?
    private var clapperTriggered = Set<Int>()
    
    var onPhaseChange: ((Phase, Phase) -> Void)?
    var onClapper: (() -> Void)?
    var onTick: ((TimeInterval) -> Void)?
    
    func start(configuration: TimerConfiguration) {
        guard configuration.isValid else { return }
        
        stop()
        
        session = TimerSession(
            configuration: configuration,
            startTime: Date()
        )
        clapperTriggered.removeAll()
        isPaused = false
        
        // Set initial phase immediately
        if let currentSession = session {
            let newPhase = currentSession.currentPhase(at: Date())
            if newPhase != phase {
                let oldPhase = phase
                phase = newPhase
                onPhaseChange?(oldPhase, newPhase)
            }
        }
        
        startTimer()
    }
    
    func pause() {
        guard var currentSession = session, !isPaused else { return }
        
        currentSession.pausedAt = Date()
        session = currentSession
        isPaused = true
        stopTimer()
    }
    
    func resume() {
        guard var currentSession = session, isPaused else { return }
        
        let pauseDuration = currentSession.pausedAt?.distance(to: Date()) ?? 0
        currentSession.accumulatedPauseTime += pauseDuration
        currentSession.pausedAt = nil
        session = currentSession
        isPaused = false
        
        startTimer()
    }
    
    func stop() {
        stopTimer()
        let oldPhase = phase
        phase = .idle
        session = nil
        timeRemaining = 0
        isPaused = false
        clapperTriggered.removeAll()
        
        if oldPhase != .idle {
            onPhaseChange?(oldPhase, .idle)
        }
    }
    
    private func startTimer() {
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @MainActor
    private func tick() {
        guard let currentSession = session, !isPaused else { return }
        
        let now = Date()
        let newPhase = currentSession.currentPhase(at: now)
        
        if newPhase != phase {
            let oldPhase = phase
            phase = newPhase
            onPhaseChange?(oldPhase, newPhase)
            
            if newPhase == .done {
                stop()
                return
            }
        }
        
        timeRemaining = currentSession.timeRemaining(in: newPhase, at: now)
        onTick?(timeRemaining)
        
        if case .work(let round, _) = newPhase {
            let clapperKey = round * 1000 + Int(timeRemaining)
            if currentSession.shouldTriggerClapper(at: now) && !clapperTriggered.contains(clapperKey) {
                clapperTriggered.insert(clapperKey)
                onClapper?()
            }
        }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func formatTimeWithTenths(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int(round(time.truncatingRemainder(dividingBy: 1) * 10)) % 10
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}