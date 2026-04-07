import SwiftUI
import Charts

struct DistanceChartView: View {
    let history: DistanceHistory
    let threshold: Double
    @State private var selectedWindow: ChartTimeWindow = .thirtyMinutes
    @State private var chartPoints: [HistoryPoint] = []
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Time", selection: $selectedWindow) {
                ForEach(ChartTimeWindow.allCases, id: \.self) { window in
                    Text(window.label).tag(window)
                }
            }
            .pickerStyle(.segmented)

            if chartPoints.isEmpty {
                Text("No data yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            } else {
                Chart {
                    ForEach(Array(chartPoints.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Distance", point.distance)
                        )
                        .foregroundStyle(lineColor(for: point.distance).opacity(0.15))

                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Distance", point.distance)
                        )
                        .foregroundStyle(lineColor(for: point.distance))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }

                    RuleMark(y: .value("Threshold", threshold))
                        .foregroundStyle(.orange.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("\(String(format: "%.0f", threshold))m")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                }
                .frame(height: 150)
                .chartXScale(domain: xDomain)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text("\(Int(d))m")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel(format: .dateTime.hour().minute())
                        AxisGridLine()
                    }
                }
            }
        }
        .padding()
        .onChange(of: selectedWindow) { _, _ in
            reloadPoints()
        }
        .onAppear {
            reloadPoints()
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private var xDomain: ClosedRange<Date> {
        let now = Date()
        let start = now.addingTimeInterval(-selectedWindow.rawValue)
        return start...now
    }

    private func reloadPoints() {
        chartPoints = history.downsampledReadings(for: selectedWindow, maxPoints: 500)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in
                reloadPoints()
            }
        }
    }

    private func lineColor(for distance: Double) -> Color {
        if distance > threshold { return .red }
        if distance > threshold * 0.8 { return .yellow }
        return .green
    }
}
