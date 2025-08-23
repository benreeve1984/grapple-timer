import SwiftUI

struct ControlRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    let step: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button(action: {
                    value = max(range.lowerBound, value - step)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.semibold)
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 60)
                
                Button(action: {
                    value = min(range.upperBound, value + step)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PresetChip: View {
    let preset: TimerPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(preset.name)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ErrorBanner: View {
    let message: String
    let type: BannerType
    
    enum BannerType {
        case error, warning, info
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.footnote)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(type.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.horizontal)
    }
}