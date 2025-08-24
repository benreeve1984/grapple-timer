import SwiftUI
import UIKit

struct SessionView: View {
    @ObservedObject var timerEngine: TimerEngine
    @StateObject private var configStore = ConfigStore.shared
    @StateObject private var notificationScheduler = NotificationScheduler.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var orientation = UIDevice.current.orientation
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact || 
        orientation == .landscapeLeft || 
        orientation == .landscapeRight
    }
    
    private var progress: Double {
        guard let session = timerEngine.session else { return 0 }
        
        switch timerEngine.phase {
        case .work(_, _):
            let totalTime = session.configuration.roundDuration
            let remaining = timerEngine.timeRemaining
            return 1.0 - (remaining / totalTime)
            
        case .rest(_, _):
            let totalTime = session.configuration.restDuration
            let remaining = timerEngine.timeRemaining
            return 1.0 - (remaining / totalTime)
            
        case .starting(let countdown):
            let totalTime = session.configuration.startDelay
            return totalTime > 0 ? 1.0 - (Double(countdown) / totalTime) : 0
            
        default:
            return 0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLandscape {
                    landscapeLayout(geometry: geometry)
                } else {
                    portraitLayout(geometry: geometry)
                }
            }
        }
        .statusBar(hidden: isLandscape)
        .persistentSystemOverlays(isLandscape ? .hidden : .automatic)
        .onAppear {
            setupSession()
        }
        .onDisappear {
            cleanupSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientation = UIDevice.current.orientation
        }
    }
    
    @ViewBuilder
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, geometry.safeAreaInsets.top)
            
            Spacer(minLength: 20)
            
            ZStack {
                ProgressRing(
                    progress: progress,
                    phase: timerEngine.phase,
                    lineWidth: 12
                )
                .frame(width: min(geometry.size.width * 0.8, 300),
                       height: min(geometry.size.width * 0.8, 300))
                
                VStack(spacing: 8) {
                    Text(timerEngine.phase.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(phaseColor)
                    
                    BigTimerDisplay(
                        time: timerEngine.timeRemaining,
                        showTenths: configStore.settings.showTenths,
                        phase: timerEngine.phase
                    )
                    .frame(height: 80)
                    
                    if case .work(let round, let total) = timerEngine.phase {
                        Text("Round \(round) of \(total)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    } else if case .rest(let round, _) = timerEngine.phase {
                        Text("Rest after round \(round)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer(minLength: 20)
            
            controlButtons
                .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
        }
    }
    
    @ViewBuilder
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        ZStack {
            // Progress ring first (background layer)
            ProgressRing(
                progress: progress,
                phase: timerEngine.phase,
                lineWidth: 4
            )
            .opacity(0.3)
            .padding(40)
            
            // Timer display (middle layer)
            BigTimerDisplay(
                time: timerEngine.timeRemaining,
                showTenths: configStore.settings.showTenths,
                phase: timerEngine.phase
            )
            .frame(width: geometry.size.width * 0.9,
                   height: geometry.size.height * 0.85)
            
            // Controls (top layer)
            VStack {
                HStack {
                    Button(action: { 
                stopSession()
            }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(timerEngine.phase.displayName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(phaseColor)
                        
                        if case .work(let round, let total) = timerEngine.phase {
                            Text("\(round)/\(total)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                HStack(spacing: 30) {
                    if timerEngine.isPaused {
                        Button(action: { timerEngine.resume() }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.green)
                        }
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.8))
                                .frame(width: 60, height: 60)
                        )
                    } else if timerEngine.phase.isActive {
                        Button(action: { timerEngine.pause() }) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.orange)
                        }
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.8))
                                .frame(width: 60, height: 60)
                        )
                    }
                    
                    Button(action: { stopSession() }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.red)
                    }
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .frame(width: 60, height: 60)
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.7))
                        .blur(radius: 10)
                )
                .padding(.bottom, 20)
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: { 
                stopSession()
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Text(timerEngine.phase.displayName)
                .font(.headline)
                .foregroundColor(phaseColor)
            
            Spacer()
            
            if case .work(let round, let total) = timerEngine.phase {
                Text("Round \(round)/\(total)")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 40) {
            if timerEngine.isPaused {
                Button(action: { timerEngine.resume() }) {
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                        Text("Resume")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            } else if timerEngine.phase.isActive {
                Button(action: { timerEngine.pause() }) {
                    VStack(spacing: 8) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 60))
                        Text("Pause")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }
            
            Button(action: { stopSession() }) {
                VStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 60))
                    Text("Stop")
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private var phaseColor: Color {
        switch timerEngine.phase {
        case .work:
            return .green
        case .rest:
            return .blue
        case .starting:
            return .orange
        case .done:
            return .gray
        default:
            return .white
        }
    }
    
    private func setupSession() {
        if configStore.settings.keepScreenAwake {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        
        AudioCue.shared.prepareForSession()
        
        if let session = timerEngine.session {
            Task {
                await notificationScheduler.scheduleSessionNotifications(for: session)
            }
        }
    }
    
    private func cleanupSession() {
        UIApplication.shared.isIdleTimerDisabled = false
        AudioCue.shared.endSession()
        
        Task {
            await notificationScheduler.clearAllNotifications()
        }
    }
    
    private func stopSession() {
        timerEngine.stop()
        
        // Clean up resources
        UIApplication.shared.isIdleTimerDisabled = false
        AudioCue.shared.endSession()
        
        // Stop music if it's playing
        if configStore.settings.musicMode != .noMusic {
            Task {
                try? await SpotifyControl.shared.pause()
            }
        }
        
        Task {
            await NotificationScheduler.shared.clearAllNotifications()
        }
        
        dismiss()
    }
}