import XCTest
@testable import GrappleTimer

final class TimerEngineTests: XCTestCase {
    
    var timerEngine: TimerEngine!
    
    override func setUp() async throws {
        await MainActor.run {
            timerEngine = TimerEngine()
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            timerEngine.stop()
            timerEngine = nil
        }
    }
    
    func testInitialState() async {
        await MainActor.run {
            XCTAssertEqual(timerEngine.phase, .idle)
            XCTAssertNil(timerEngine.session)
            XCTAssertEqual(timerEngine.timeRemaining, 0)
            XCTAssertFalse(timerEngine.isPaused)
        }
    }
    
    func testStartWithValidConfiguration() async {
        let config = TimerConfiguration(
            roundDuration: 300,
            restDuration: 60,
            rounds: 5,
            clapperTime: 10,
            startDelay: 0
        )
        
        await MainActor.run {
            timerEngine.start(configuration: config)
            
            XCTAssertNotNil(timerEngine.session)
            XCTAssertEqual(timerEngine.session?.configuration, config)
            XCTAssertFalse(timerEngine.isPaused)
        }
    }
    
    func testPhaseTransitions() async {
        let config = TimerConfiguration(
            roundDuration: 5,
            restDuration: 3,
            rounds: 2,
            clapperTime: 1,
            startDelay: 0
        )
        
        await MainActor.run {
            var phases: [Phase] = []
            
            timerEngine.onPhaseChange = { _, newPhase in
                phases.append(newPhase)
            }
            
            timerEngine.start(configuration: config)
            
            XCTAssertEqual(timerEngine.phase, .work(round: 1, totalRounds: 2))
        }
    }
    
    func testPauseAndResume() async {
        let config = TimerConfiguration(
            roundDuration: 10,
            restDuration: 5,
            rounds: 1,
            clapperTime: 2,
            startDelay: 0
        )
        
        await MainActor.run {
            timerEngine.start(configuration: config)
            
            timerEngine.pause()
            XCTAssertTrue(timerEngine.isPaused)
            XCTAssertNotNil(timerEngine.session?.pausedAt)
            
            timerEngine.resume()
            XCTAssertFalse(timerEngine.isPaused)
            XCTAssertNil(timerEngine.session?.pausedAt)
        }
    }
    
    func testInvalidConfiguration() async {
        let invalidConfig = TimerConfiguration(
            roundDuration: 10,
            restDuration: 5,
            rounds: 1,
            clapperTime: 15,
            startDelay: 0
        )
        
        await MainActor.run {
            XCTAssertFalse(invalidConfig.isValid)
            
            timerEngine.start(configuration: invalidConfig)
            XCTAssertNil(timerEngine.session)
            XCTAssertEqual(timerEngine.phase, .idle)
        }
    }
    
    func testTimeFormatting() async {
        await MainActor.run {
            XCTAssertEqual(timerEngine.formatTime(125), "2:05")
            XCTAssertEqual(timerEngine.formatTime(59), "0:59")
            XCTAssertEqual(timerEngine.formatTime(600), "10:00")
            XCTAssertEqual(timerEngine.formatTime(0), "0:00")
            
            XCTAssertEqual(timerEngine.formatTimeWithTenths(125.5), "2:05.5")
            XCTAssertEqual(timerEngine.formatTimeWithTenths(59.9), "0:59.9")
            XCTAssertEqual(timerEngine.formatTimeWithTenths(0.1), "0:00.1")
        }
    }
    
    func testSessionCalculations() {
        let config = TimerConfiguration(
            roundDuration: 300,
            restDuration: 60,
            rounds: 5,
            clapperTime: 10,
            startDelay: 3
        )
        
        let session = TimerSession(
            configuration: config,
            startTime: Date()
        )
        
        let expectedTotal = 3 + (300 * 5) + (60 * 4)
        XCTAssertEqual(session.totalDuration, TimeInterval(expectedTotal))
        
        let futureDate = Date().addingTimeInterval(10)
        let elapsed = session.elapsedTime(at: futureDate)
        XCTAssertEqual(elapsed, 10, accuracy: 0.1)
        
        let phase = session.currentPhase(at: Date().addingTimeInterval(4))
        XCTAssertEqual(phase, .work(round: 1, totalRounds: 5))
    }
    
    func testClapperTrigger() {
        let config = TimerConfiguration(
            roundDuration: 30,
            restDuration: 10,
            rounds: 1,
            clapperTime: 10,
            startDelay: 0
        )
        
        let session = TimerSession(
            configuration: config,
            startTime: Date()
        )
        
        let beforeClapper = Date().addingTimeInterval(19)
        XCTAssertFalse(session.shouldTriggerClapper(at: beforeClapper))
        
        let atClapper = Date().addingTimeInterval(20)
        XCTAssertTrue(session.shouldTriggerClapper(at: atClapper))
        
        let afterClapper = Date().addingTimeInterval(25)
        XCTAssertFalse(session.shouldTriggerClapper(at: afterClapper))
    }
    
    func testNextPhaseTransitions() {
        let config = TimerConfiguration(
            roundDuration: 60,
            restDuration: 30,
            rounds: 3,
            clapperTime: 5,
            startDelay: 3
        )
        
        let session = TimerSession(
            configuration: config,
            startTime: Date()
        )
        
        XCTAssertEqual(
            session.nextPhase(after: .idle),
            .starting(countdown: 3)
        )
        
        XCTAssertEqual(
            session.nextPhase(after: .starting(countdown: 3)),
            .work(round: 1, totalRounds: 3)
        )
        
        XCTAssertEqual(
            session.nextPhase(after: .work(round: 1, totalRounds: 3)),
            .rest(round: 1, totalRounds: 3)
        )
        
        XCTAssertEqual(
            session.nextPhase(after: .rest(round: 1, totalRounds: 3)),
            .work(round: 2, totalRounds: 3)
        )
        
        XCTAssertEqual(
            session.nextPhase(after: .work(round: 3, totalRounds: 3)),
            .done
        )
        
        XCTAssertNil(session.nextPhase(after: .done))
    }
}