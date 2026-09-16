import SwiftUI
import Charts

/// Visual learning dashboard: rings, deck composition, and recent activity.
struct StudyStatsDashboard: View {
    let stats: StudyStatsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Learning overview")
                .font(.headline)

            ringsRow
            deckComposition
            activityChart
            highlightRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.appTextBackground)
        )
    }

    private var ringsRow: some View {
        HStack(spacing: 18) {
            ProgressRing(
                title: "Accuracy",
                value: stats.accuracy,
                caption: stats.reviewCount == 0 ? "No reviews yet" : "\(stats.correctCount)/\(stats.reviewCount)",
                color: Color(hex: "0F766E") ?? .teal
            )
            ProgressRing(
                title: "Mastered",
                value: stats.masteryRate,
                caption: "\(stats.masteredCount) of \(stats.studyableCards)",
                color: Color(hex: "16A34A") ?? .green
            )
            ProgressRing(
                title: "Coverage",
                value: stats.coverageRate,
                caption: "\(stats.studyableCards) studyable",
                color: Color(hex: "0369A1") ?? .blue
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var deckComposition: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deck status")
                .font(.subheadline.weight(.semibold))

            let total = max(stats.deckSegments.map(\.count).reduce(0, +), 1)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(stats.deckSegments, id: \.segment) { item in
                        if item.count > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: item.segment.color) ?? .secondary)
                                .frame(width: max(4, geo.size.width * CGFloat(item.count) / CGFloat(total)))
                                .help("\(item.segment.title): \(item.count)")
                        }
                    }
                }
            }
            .frame(height: 14)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(stats.deckSegments, id: \.segment) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: item.segment.color) ?? .secondary)
                            .frame(width: 8, height: 8)
                        Text(item.segment.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text("\(item.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last 14 days")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Reviews / day")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Chart {
                ForEach(stats.recentDays) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Count", day.correct)
                    )
                    .foregroundStyle(by: .value("Result", "Remembered"))
                    .cornerRadius(2)

                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Count", max(0, day.reviews - day.correct))
                    )
                    .foregroundStyle(by: .value("Result", "Again"))
                    .cornerRadius(2)
                }
            }
            .chartForegroundStyleScale([
                "Remembered": Color(hex: "16A34A") ?? .green,
                "Again": Color(hex: "D97706") ?? .orange,
            ])
            .chartLegend(position: .bottom, alignment: .leading)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .frame(height: 150)

            HStack {
                Spacer()
                if stats.streakDays > 0 {
                    Label("\(stats.streakDays)-day streak", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "EA580C") ?? .orange)
                }
            }
        }
    }

    private var highlightRow: some View {
        HStack(spacing: 10) {
            metricChip(title: "Due now", value: "\(stats.dueCount)", tint: "D97706")
            metricChip(title: "Today", value: "\(stats.reviewedToday)", tint: "0284C7")
            metricChip(title: "Total reviews", value: "\(stats.reviewCount)", tint: "57534E")
        }
    }

    private func metricChip(title: String, value: String, tint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color(hex: tint) ?? .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((Color(hex: tint) ?? .secondary).opacity(0.1))
        )
    }
}

private struct ProgressRing: View {
    let title: String
    let value: Double
    let caption: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(value, 0), 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: value)
                Text(percentLabel)
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 78, height: 78)

            Text(title)
                .font(.caption.weight(.semibold))
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 100)
        }
        .frame(maxWidth: .infinity)
    }

    private var percentLabel: String {
        if value <= 0 { return "0%" }
        return "\(Int((value * 100).rounded()))%"
    }
}
