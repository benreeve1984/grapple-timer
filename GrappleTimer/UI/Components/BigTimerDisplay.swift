import SwiftUI

struct BigTimerDisplay: View {
    let time: TimeInterval
    let showTenths: Bool
    let phase: Phase
    
    private var formattedTime: String {
        if showTenths && time < 60 {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
            return String(format: "%d:%02d.%d", minutes, seconds, tenths)
        } else {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private var phaseColor: Color {
        switch phase {
        case .work:
            return .green
        case .rest:
            return .blue
        case .starting:
            return .orange
        case .done:
            return .gray
        default:
            return .primary
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            Text(formattedTime)
                .font(.system(size: min(geometry.size.width * 0.25, geometry.size.height * 0.7), weight: .bold, design: .monospaced))
                .foregroundColor(phaseColor)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    let phase: Phase
    let lineWidth: CGFloat
    
    private var ringColor: Color {
        switch phase {
        case .work:
            return .green
        case .rest:
            return .blue
        case .starting:
            return .orange
        default:
            return .gray
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.2)
                .foregroundColor(ringColor)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(ringColor)
                .rotationEffect(Angle(degrees: 270))
                .animation(.linear(duration: 0.3), value: progress)
        }
    }
}