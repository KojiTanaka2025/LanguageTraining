import Foundation

/// Direction of a flashcard prompt.
enum StudyDirection: String, CaseIterable, Identifiable, Sendable {
    case japaneseToEnglish
    case englishToJapanese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .japaneseToEnglish:
            return "日本語 → 英語＋発音"
        case .englishToJapanese:
            return "英語＋発音 → 日本語"
        }
    }

    var subtitle: String {
        switch self {
        case .japaneseToEnglish:
            return "日本語を見て英語を思い出し、発音を確認します"
        case .englishToJapanese:
            return "英語と発音を聞いて、日本語の意味を思い浮かべます"
        }
    }
}

/// Per-card spaced-repetition state (SM-2 inspired).
struct StudyProgress: Identifiable, Hashable, Sendable {
    var cardID: UUID
    var easeFactor: Double
    var intervalDays: Double
    var repetitions: Int
    var nextReviewAt: Date
    var lastReviewedAt: Date?
    var reviewCount: Int
    var correctCount: Int
    var incorrectCount: Int

    var id: UUID { cardID }

    static let minimumEase = 1.3
    static let defaultEase = 2.5

    static func fresh(cardID: UUID, now: Date = Date()) -> StudyProgress {
        StudyProgress(
            cardID: cardID,
            easeFactor: defaultEase,
            intervalDays: 0,
            repetitions: 0,
            nextReviewAt: now,
            lastReviewedAt: nil,
            reviewCount: 0,
            correctCount: 0,
            incorrectCount: 0
        )
    }

    var accuracy: Double {
        guard reviewCount > 0 else { return 0 }
        return Double(correctCount) / Double(reviewCount)
    }

    var isDue: Bool {
        nextReviewAt <= Date()
    }

    /// How overdue the card is, in days (0 if not due yet).
    var overdueDays: Double {
        max(0, Date().timeIntervalSince(nextReviewAt) / 86_400)
    }

    /// Lower = should appear sooner in a session.
    func priorityScore(now: Date = Date(), jitter: Double) -> Double {
        let overdue = max(0, now.timeIntervalSince(nextReviewAt) / 86_400)
        let weakness = (StudyProgress.defaultEase - easeFactor) * 2
        let missRate = reviewCount == 0 ? 0.5 : Double(incorrectCount) / Double(reviewCount)
        // New / never reviewed: treat as mildly urgent.
        let novelty = reviewCount == 0 ? 1.2 : 0
        return -(overdue * 3 + weakness + missRate * 2 + novelty) + jitter
    }
}

enum StudyGrade: String, Sendable {
    case again
    case good
}

struct StudyDayRecord: Identifiable, Hashable, Sendable {
    /// Start of local calendar day.
    var day: Date
    var reviews: Int
    var correct: Int

    var id: Date { day }

    var accuracy: Double {
        guard reviews > 0 else { return 0 }
        return Double(correct) / Double(reviews)
    }

    var dayKey: String {
        StudyDayRecord.dayFormatter.string(from: day)
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func parseDayKey(_ key: String, calendar: Calendar = .current) -> Date? {
        guard let date = dayFormatter.date(from: key) else { return nil }
        return calendar.startOfDay(for: date)
    }
}

enum StudyDeckSegment: String, CaseIterable, Identifiable, Sendable {
    case due
    case new
    case learning
    case mastered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .due: return "Due"
        case .new: return "New"
        case .learning: return "Learning"
        case .mastered: return "Mastered"
        }
    }

    var color: String {
        // Hex used by SwiftUI Color(hex:)
        switch self {
        case .due: return "D97706"      // amber
        case .new: return "64748B"      // slate
        case .learning: return "0284C7" // sky
        case .mastered: return "16A34A" // green
        }
    }
}

enum StudyScheduler {
    /// Build a review queue: due / weak cards first, with shuffle so order is not fixed.
    static func buildQueue(
        cards: [Card],
        progress: [UUID: StudyProgress],
        limit: Int = 40,
        now: Date = Date()
    ) -> [UUID] {
        let studyable = cards.filter { CardStudyContent.canStudy($0) }
        guard !studyable.isEmpty else { return [] }

        let scored: [(UUID, Double)] = studyable.map { card in
            let state = progress[card.id] ?? StudyProgress.fresh(cardID: card.id, now: now)
            // Skip cards scheduled far in the future unless we still need filler new cards.
            let jitter = Double.random(in: -0.35...0.35)
            var score = state.priorityScore(now: now, jitter: jitter)
            if state.nextReviewAt > now.addingTimeInterval(86_400) {
                // More than a day ahead: deprioritize heavily but keep a little randomness.
                score += 10
            }
            return (card.id, score)
        }

        return scored
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    static func apply(
        grade: StudyGrade,
        to progress: StudyProgress,
        now: Date = Date()
    ) -> StudyProgress {
        var next = progress
        next.lastReviewedAt = now
        next.reviewCount += 1

        switch grade {
        case .again:
            next.incorrectCount += 1
            next.repetitions = 0
            next.intervalDays = 0
            next.easeFactor = max(StudyProgress.minimumEase, next.easeFactor - 0.2)
            // Retry soon in the same day (about 10 minutes).
            next.nextReviewAt = now.addingTimeInterval(10 * 60)
        case .good:
            next.correctCount += 1
            if next.repetitions == 0 {
                next.intervalDays = 1
                next.repetitions = 1
            } else if next.repetitions == 1 {
                next.intervalDays = 3
                next.repetitions = 2
            } else {
                next.intervalDays = max(1, next.intervalDays * next.easeFactor)
                next.repetitions += 1
            }
            next.easeFactor = min(3.0, next.easeFactor + 0.05)
            let seconds = next.intervalDays * 86_400
            next.nextReviewAt = now.addingTimeInterval(seconds)
        }
        return next
    }
}

struct StudyStatsSummary: Sendable {
    var totalCards: Int
    var studyableCards: Int
    var dueCount: Int
    var newCount: Int
    var overdueCount: Int
    var learningCount: Int
    var masteredCount: Int
    var reviewCount: Int
    var correctCount: Int
    var incorrectCount: Int
    var averageEase: Double
    var reviewedToday: Int
    var streakDays: Int
    var recentDays: [StudyDayRecord]

    var accuracy: Double {
        guard reviewCount > 0 else { return 0 }
        return Double(correctCount) / Double(reviewCount)
    }

    var masteryRate: Double {
        guard studyableCards > 0 else { return 0 }
        return Double(masteredCount) / Double(studyableCards)
    }

    var coverageRate: Double {
        guard totalCards > 0 else { return 0 }
        return Double(studyableCards) / Double(totalCards)
    }

    var deckSegments: [(segment: StudyDeckSegment, count: Int)] {
        [
            (.due, overdueCount),
            (.new, newCount),
            (.learning, learningCount),
            (.mastered, masteredCount),
        ]
    }

    static func build(
        cards: [Card],
        progress: [UUID: StudyProgress],
        dailyLog: [StudyDayRecord] = [],
        now: Date = Date()
    ) -> StudyStatsSummary {
        let studyable = cards.filter { CardStudyContent.canStudy($0) }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)

        var neu = 0
        var overdue = 0
        var learning = 0
        var mastered = 0
        var reviews = 0
        var correct = 0
        var incorrect = 0
        var easeSum = 0.0
        var easeN = 0
        var reviewedToday = 0
        var reviewDays = Set<DateComponents>()

        for card in studyable {
            if let state = progress[card.id] {
                let isMastered = state.repetitions >= 3 && state.intervalDays >= 21
                if isMastered {
                    mastered += 1
                } else if state.reviewCount == 0 {
                    neu += 1
                } else if state.nextReviewAt <= now {
                    overdue += 1
                } else {
                    learning += 1
                }
                reviews += state.reviewCount
                correct += state.correctCount
                incorrect += state.incorrectCount
                easeSum += state.easeFactor
                easeN += 1
                if let last = state.lastReviewedAt {
                    if last >= startOfDay { reviewedToday += 1 }
                    reviewDays.insert(calendar.dateComponents([.year, .month, .day], from: last))
                }
            } else {
                neu += 1
            }
        }

        // Prefer persisted daily log; fill missing days for a stable 14-day chart.
        let recent = paddedRecentDays(from: dailyLog, calendar: calendar, now: now, days: 14)
        for record in dailyLog where record.reviews > 0 {
            reviewDays.insert(calendar.dateComponents([.year, .month, .day], from: record.day))
        }

        return StudyStatsSummary(
            totalCards: cards.count,
            studyableCards: studyable.count,
            dueCount: overdue + neu,
            newCount: neu,
            overdueCount: overdue,
            learningCount: learning,
            masteredCount: mastered,
            reviewCount: reviews,
            correctCount: correct,
            incorrectCount: incorrect,
            averageEase: easeN == 0 ? StudyProgress.defaultEase : easeSum / Double(easeN),
            reviewedToday: reviewedToday,
            streakDays: streakLength(days: reviewDays, calendar: calendar, now: now),
            recentDays: recent
        )
    }

    private static func paddedRecentDays(
        from log: [StudyDayRecord],
        calendar: Calendar,
        now: Date,
        days: Int
    ) -> [StudyDayRecord] {
        let byDay = Dictionary(uniqueKeysWithValues: log.map { (calendar.startOfDay(for: $0.day), $0) })
        var result: [StudyDayRecord] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) else { continue }
            if let existing = byDay[day] {
                result.append(existing)
            } else {
                result.append(StudyDayRecord(day: day, reviews: 0, correct: 0))
            }
        }
        return result
    }

    private static func streakLength(days: Set<DateComponents>, calendar: Calendar, now: Date) -> Int {
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        // Allow streak to count yesterday if nothing today yet.
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: cursor)
        if !days.contains(todayComponents) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        while true {
            let components = calendar.dateComponents([.year, .month, .day], from: cursor)
            guard days.contains(components) else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
