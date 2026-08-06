import SwiftUI
import Charts

struct SessionGraphView: View {
    let session: Session
    @EnvironmentObject var theme: AppThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedPoint: MoodLog?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Summary")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Label("\(session.durationInMinutes) min", systemImage: "clock")
                            Spacer()
                            Label("\(session.averageMood)% avg", systemImage: "heart.fill")
                                .foregroundColor(.green)
                            Spacer()
                            Label("\(session.moodLogs.count) logs", systemImage: "list.bullet")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Main Graph
                    if session.moodLogs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No mood logs recorded")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Satisfaction Over Time")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Chart
                            Chart {
                                ForEach(session.moodLogs, id: \.id) { log in
                                    LineMark(
                                        x: .value("Time", log.timestamp / 60),
                                        y: .value("Mood", log.satisfaction)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: theme.chartColors,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )

                                    PointMark(
                                        x: .value("Time", log.timestamp / 60),
                                        y: .value("Mood", log.satisfaction)
                                    )
                                    .foregroundStyle(theme.accentColor)
                                    .symbolSize(selectedPoint?.id == log.id ? 100 : 30)
                                    .annotation(position: .overlay) {
                                        if selectedPoint?.id == log.id {
                                            Text(log.note.isEmpty ? "\(log.satisfaction)%" : log.note)
                                                .font(.caption)
                                                .padding(6)
                                                .background(theme.configuration.surface)
                                                .cornerRadius(6)
                                                .shadow(radius: 2)
                                        }
                                    }
                                }
                            }
                            .frame(height: 300)
                            .chartXAxis {
                                AxisMarks { value in
                                    AxisValueLabel()
                                    AxisTick()
                                }
                            }
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisValueLabel()
                                    AxisTick()
                                }
                            }
                            .chartXAxisLabel("Minutes", position: .bottom)
                            .chartYAxisLabel("Satisfaction", position: .leading)
                            .padding(.horizontal)
                        }
                        .background(theme.configuration.surface)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Mood Logs List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mood Logs")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(session.moodLogs.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { log in
                            HStack {
                                Circle()
                                    .fill(colorForSatisfaction(log.satisfaction))
                                    .frame(width: 10, height: 10)
                                
                                Text("\(Int(log.timestamp / 60))m")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .leading)
                                
                                Text("\(log.satisfaction)%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 50, alignment: .leading)
                                
                                Text(log.note.isEmpty ? "No note" : log.note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(theme.configuration.surface.opacity(0.5))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
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
    
    private func colorForSatisfaction(_ value: Int) -> Color {
        switch value {
        case 0..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        case 70..<90: return .green
        default: return .blue
        }
    }
}
