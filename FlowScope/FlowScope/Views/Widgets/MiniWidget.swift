import SwiftUI

// MARK: - Mini Widget Preview for App
struct MiniWidget: View {
    @EnvironmentObject var themeManager: ThemeManager
    private var config: ThemeConfiguration { themeManager.configuration }

    let moodData: [(date: Date, mood: Int)]
    let size: WidgetSize
    
    enum WidgetSize {
        case small
        case medium
        
        var height: CGFloat {
            switch self {
            case .small: return 80
            case .medium: return 120
            }
        }
    }
    
    init(moodData: [(date: Date, mood: Int)] = [], size: WidgetSize = .small) {
        self.moodData = moodData
        self.size = size
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(config.primary)
                    .font(.caption)
                
                Text("FlowScope")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !moodData.isEmpty {
                    Text("\(moodData.count) logs")
                        .font(.caption2)
                        .foregroundStyle(config.textSecondary)
                }
            }
            
            if moodData.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.title2)
                            .foregroundStyle(config.primary.opacity(0.6))
                        Text("Start a session")
                            .font(.caption2)
                            .foregroundStyle(config.textSecondary)
                    }
                    Spacer()
                }
                .frame(height: size == .small ? 40 : 60)
            } else {
                // Mini Graph
                let moods = moodData.map { Double($0.mood) / 100.0 }
                let normalizedMoods = moods.map { 1.0 - $0 }
                
                GeometryReader { geometry in
                    Path { path in
                        guard !normalizedMoods.isEmpty else { return }
                        
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let step = width / CGFloat(max(normalizedMoods.count - 1, 1))
                        
                        path.move(to: CGPoint(x: 0, y: height * normalizedMoods[0]))
                        
                        for index in 1..<normalizedMoods.count {
                            let x = CGFloat(index) * step
                            let y = height * normalizedMoods[index]
                            
                            // Smooth curve
                            let prevX = CGFloat(index - 1) * step
                            let prevY = height * normalizedMoods[index - 1]
                            let midX = (prevX + x) / 2
                            
                            path.addQuadCurve(
                                to: CGPoint(x: x, y: y),
                                control: CGPoint(x: midX, y: prevY)
                            )
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: config.chartColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(height: size == .small ? 30 : 50)
                
                if size == .medium {
                    HStack {
                        let avgMood = moodData.reduce(0) { $0 + $1.mood } / max(moodData.count, 1)
                        Text("Average: \(avgMood)%")
                            .font(.caption)
                            .foregroundStyle(config.textSecondary)
                        
                        Spacer()
                        
                        if let latest = moodData.last {
                            Text("Latest: \(latest.mood)%")
                                .font(.caption)
                                .foregroundStyle(config.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(size == .small ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                .fill(config.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                        .stroke(config.primary.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: config.primary.opacity(0.2), radius: 6, x: 0, y: 2)
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        MiniWidget(moodData: [
            (Date(), 40),
            (Date().addingTimeInterval(300), 60),
            (Date().addingTimeInterval(600), 80),
            (Date().addingTimeInterval(900), 75),
            (Date().addingTimeInterval(1200), 90)
        ], size: .small)
        
        MiniWidget(moodData: [
            (Date(), 40),
            (Date().addingTimeInterval(300), 60),
            (Date().addingTimeInterval(600), 80),
            (Date().addingTimeInterval(900), 75),
            (Date().addingTimeInterval(1200), 90)
        ], size: .medium)
        
        MiniWidget(moodData: [], size: .small)
    }
    .padding()
    .environmentObject(ThemeManager.shared)
}
