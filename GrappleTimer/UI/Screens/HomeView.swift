import SwiftUI
import UIKit

struct HomeView: View {
    @StateObject private var timerEngine = TimerEngine()
    @StateObject private var configStore = ConfigStore.shared
    @StateObject private var spotifyControl = SpotifyControl.shared
    @StateObject private var audioCue = AudioCue.shared
    
    @State private var selectedPreset: TimerPreset?
    @State private var showingSession = false
    @State private var showingSettings = false
    @State private var errorMessage: String?
    @State private var isLandscape = UIDevice.current.orientation.isLandscape
    
    @State private var roundMinutes: Int = 5
    @State private var roundSeconds: Int = 0
    @State private var restMinutes: Int = 1
    @State private var restSeconds: Int = 0
    @State private var rounds: Int = 5
    @State private var clapperSeconds: Int = 10
    
    var totalRoundSeconds: Int {
        roundMinutes * 60 + roundSeconds
    }
    
    var totalRestSeconds: Int {
        restMinutes * 60 + restSeconds
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if !isLandscape {
                        presetsSection
                    }
                    
                    controlsSection
                    
                    if let error = errorMessage {
                        ErrorBanner(message: error, type: .warning)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    startButton
                    
                    musicSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Grapple Timer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingSession) {
                SessionView(timerEngine: timerEngine)
            }
        }
        .onAppear {
            loadConfiguration()
            setupTimerCallbacks()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation {
                isLandscape = UIDevice.current.orientation.isLandscape
            }
        }
    }
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRESETS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(configStore.presets) { preset in
                        PresetChip(
                            preset: preset,
                            isSelected: selectedPreset?.id == preset.id,
                            action: {
                                selectPreset(preset)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("ROUND")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Picker("Minutes", selection: $roundMinutes) {
                            ForEach(0...10, id: \.self) { min in
                                Text("\(min)").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 100)
                        .clipped()
                        
                        Text(":")
                            .font(.title2)
                        
                        Picker("Seconds", selection: $roundSeconds) {
                            ForEach(0...59, id: \.self) { sec in
                                Text(String(format: "%02d", sec)).tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 100)
                        .clipped()
                    }
                }
                
                VStack(spacing: 8) {
                    Text("REST")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Picker("Minutes", selection: $restMinutes) {
                            ForEach(0...5, id: \.self) { min in
                                Text("\(min)").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 100)
                        .clipped()
                        
                        Text(":")
                            .font(.title2)
                        
                        Picker("Seconds", selection: $restSeconds) {
                            ForEach(0...59, id: \.self) { sec in
                                Text(String(format: "%02d", sec)).tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 50, height: 100)
                        .clipped()
                    }
                }
            }
            
            HStack(spacing: 30) {
                ControlRow(
                    label: "ROUNDS",
                    value: $rounds,
                    range: 1...20,
                    unit: "rounds",
                    step: 1
                )
                
                ControlRow(
                    label: "CLAPPER",
                    value: $clapperSeconds,
                    range: 0...30,
                    unit: "seconds",
                    step: 5
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var startButton: some View {
        Button(action: startSession) {
            HStack {
                Image(systemName: "play.fill")
                Text("START SESSION")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .disabled(!isConfigurationValid())
    }
    
    private var musicSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: spotifyControl.isConnected ? "music.note" : "music.note")
                    .foregroundColor(spotifyControl.isConnected ? .green : .secondary)
                
                Text(spotifyControl.isConnected ? "Spotify Connected" : "Spotify Not Connected")
                    .font(.footnote)
                
                Spacer()
                
                if !spotifyControl.isConnected {
                    Button("Connect") {
                        Task {
                            try? await spotifyControl.connect()
                        }
                    }
                    .font(.footnote)
                }
            }
            .padding(.horizontal)
            
            if let error = spotifyControl.currentError {
                ErrorBanner(message: error.localizedDescription, type: .info)
            }
        }
    }
    
    private func selectPreset(_ preset: TimerPreset) {
        selectedPreset = preset
        let config = preset.configuration
        roundMinutes = Int(config.roundDuration) / 60
        roundSeconds = Int(config.roundDuration) % 60
        restMinutes = Int(config.restDuration) / 60
        restSeconds = Int(config.restDuration) % 60
        rounds = config.rounds
        clapperSeconds = Int(config.clapperTime)
    }
    
    private func loadConfiguration() {
        let config = configStore.currentConfiguration
        roundMinutes = Int(config.roundDuration) / 60
        roundSeconds = Int(config.roundDuration) % 60
        restMinutes = Int(config.restDuration) / 60
        restSeconds = Int(config.restDuration) % 60
        rounds = config.rounds
        clapperSeconds = Int(config.clapperTime)
    }
    
    private func isConfigurationValid() -> Bool {
        return totalRoundSeconds > 0 && 
               totalRestSeconds > 0 && 
               rounds > 0 &&
               clapperSeconds < totalRoundSeconds
    }
    
    private func startSession() {
        guard isConfigurationValid() else {
            errorMessage = "Invalid configuration. Check your settings."
            return
        }
        
        let config = TimerConfiguration(
            roundDuration: TimeInterval(totalRoundSeconds),
            restDuration: TimeInterval(totalRestSeconds),
            rounds: rounds,
            clapperTime: TimeInterval(clapperSeconds),
            startDelay: configStore.settings.enableStartDelay ? 3 : 0
        )
        
        configStore.currentConfiguration = config
        timerEngine.start(configuration: config)
        showingSession = true
    }
    
    private func setupTimerCallbacks() {
        timerEngine.onPhaseChange = { oldPhase, newPhase in
            Task {
                await handlePhaseChange(from: oldPhase, to: newPhase)
            }
        }
        
        timerEngine.onClapper = {
            audioCue.playClapper()
        }
    }
    
    private func handlePhaseChange(from oldPhase: Phase, to newPhase: Phase) async {
        switch newPhase {
        case .work:
            audioCue.playBell()  // Bell at start of round
            switch configStore.settings.musicMode {
            case .noMusic:
                break  // Do nothing for music
            case .useCurrentPlayback:
                try? await spotifyControl.resume()
            case .usePlaylist(let uri):
                try? await spotifyControl.play(mode: .usePlaylist(uri: uri))
            }
            
        case .rest:
            audioCue.playHorn()  // Horn at end of round
            if configStore.settings.musicMode != .noMusic {
                try? await spotifyControl.pause()
            }
            
        case .done:
            audioCue.playHorn()
            if configStore.settings.musicMode != .noMusic {
                try? await spotifyControl.pause()
            }
            
        case .starting:
            audioCue.playStartCountdown()
            // Pause music during countdown
            if configStore.settings.musicMode != .noMusic {
                try? await spotifyControl.pause()
            }
            
        default:
            break
        }
    }
}

struct SettingsView: View {
    @StateObject private var configStore = ConfigStore.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Display") {
                    Toggle("Keep Screen Awake", isOn: $configStore.settings.keepScreenAwake)
                    Toggle("Show Tenths of Seconds", isOn: $configStore.settings.showTenths)
                }
                
                Section("Timer") {
                    Toggle("Enable Start Delay (3s)", isOn: $configStore.settings.enableStartDelay)
                }
                
                Section("Music") {
                    Picker("Music Mode", selection: $configStore.settings.musicMode) {
                        Text("No Music").tag(MusicMode.noMusic)
                        Text("Current Playback").tag(MusicMode.useCurrentPlayback)
                        Text("Custom Playlist").tag(MusicMode.usePlaylist(uri: configStore.settings.playlistURI))
                    }
                    
                    if case .usePlaylist = configStore.settings.musicMode {
                        TextField("Playlist URI", text: $configStore.settings.playlistURI)
                            .font(.footnote)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        configStore.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}