import Foundation
import Combine

struct TimerPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var configuration: TimerConfiguration
    var isDefault: Bool
    
    init(id: UUID = UUID(), name: String, configuration: TimerConfiguration, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.configuration = configuration
        self.isDefault = isDefault
    }
    
    static let defaultPresets: [TimerPreset] = [
        TimerPreset(
            name: "10×5:00/1:00",
            configuration: TimerConfiguration(
                roundDuration: 300,
                restDuration: 60,
                rounds: 10,
                clapperTime: 10,
                startDelay: 0
            ),
            isDefault: true
        ),
        TimerPreset(
            name: "15×3:00/1:00",
            configuration: TimerConfiguration(
                roundDuration: 180,
                restDuration: 60,
                rounds: 15,
                clapperTime: 10,
                startDelay: 0
            )
        ),
        TimerPreset(
            name: "5×10:00/2:00",
            configuration: TimerConfiguration(
                roundDuration: 600,
                restDuration: 120,
                rounds: 5,
                clapperTime: 10,
                startDelay: 0
            )
        )
    ]
}

struct AppSettings: Codable {
    var keepScreenAwake: Bool = true
    var showTenths: Bool = false
    var enableStartDelay: Bool = false
    var musicMode: MusicMode = .usePlaylist(uri: "spotify:playlist:2P2oppRNcZgcyyhW2dhS9k")
    var playlistURI: String = "spotify:playlist:2P2oppRNcZgcyyhW2dhS9k"
    var lastUsedConfiguration: TimerConfiguration = .default
}

@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()
    
    @Published var currentConfiguration: TimerConfiguration {
        didSet {
            saveConfiguration()
        }
    }
    
    @Published var presets: [TimerPreset] {
        didSet {
            savePresets()
        }
    }
    
    @Published var settings: AppSettings {
        didSet {
            saveSettings()
        }
    }
    
    private let userDefaults = UserDefaults.standard
    
    private struct Keys {
        static let configuration = "timer.configuration"
        static let presets = "timer.presets"
        static let settings = "app.settings"
        static let hasLaunched = "app.hasLaunched"
    }
    
    private init() {
        if let data = userDefaults.data(forKey: Keys.configuration),
           let config = try? JSONDecoder().decode(TimerConfiguration.self, from: data) {
            self.currentConfiguration = config
        } else {
            self.currentConfiguration = .default
        }
        
        if let data = userDefaults.data(forKey: Keys.settings),
           let savedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            self.settings = AppSettings()
        }
        
        if let data = userDefaults.data(forKey: Keys.presets),
           let savedPresets = try? JSONDecoder().decode([TimerPreset].self, from: data) {
            self.presets = savedPresets
        } else {
            self.presets = TimerPreset.defaultPresets
            if !userDefaults.bool(forKey: Keys.hasLaunched) {
                savePresets()
                userDefaults.set(true, forKey: Keys.hasLaunched)
            }
        }
    }
    
    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(currentConfiguration) {
            userDefaults.set(encoded, forKey: Keys.configuration)
            settings.lastUsedConfiguration = currentConfiguration
            saveSettings()
        }
    }
    
    private func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            userDefaults.set(encoded, forKey: Keys.presets)
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: Keys.settings)
        }
    }
    
    func addPreset(_ preset: TimerPreset) {
        presets.append(preset)
    }
    
    func updatePreset(_ preset: TimerPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        }
    }
    
    func deletePreset(_ preset: TimerPreset) {
        presets.removeAll { $0.id == preset.id }
    }
    
    func selectPreset(_ preset: TimerPreset) {
        currentConfiguration = preset.configuration
    }
    
    func resetToDefaults() {
        currentConfiguration = .default
        presets = TimerPreset.defaultPresets
        settings = AppSettings()
        saveConfiguration()
        savePresets()
        saveSettings()
    }
}

extension ConfigStore {
    func updateFromSiri(
        roundSeconds: Int,
        restSeconds: Int,
        rounds: Int,
        clapperSeconds: Int
    ) {
        currentConfiguration = TimerConfiguration(
            roundDuration: TimeInterval(roundSeconds),
            restDuration: TimeInterval(restSeconds),
            rounds: rounds,
            clapperTime: TimeInterval(clapperSeconds),
            startDelay: settings.enableStartDelay ? 3 : 0
        )
    }
}