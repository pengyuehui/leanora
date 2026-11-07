import Foundation

struct JournalCalendarDay: Identifiable, Sendable {
    var date: Date
    var day: String
    var isInMonth: Bool
    var id: String { day }
}

enum JournalMonth {
    // Calendar-day arithmetic at noon avoids DST's missing/repeated midnight.
    static func days(containing date: Date, timeZone: TimeZone = .current) -> [JournalCalendarDay] {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let first = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1, hour: 12)),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let leading = (calendar.component(.weekday, from: first) + 5) % 7
        let count = ((leading + range.count + 6) / 7) * 7
        return (0..<count).compactMap { index in
            guard let value = calendar.date(byAdding: .day, value: index - leading, to: first) else { return nil }
            return JournalCalendarDay(date: value, day: RecordMoment.day(value, timeZoneID: timeZone.identifier),
                                      isInMonth: calendar.isDate(value, equalTo: first, toGranularity: .month))
        }
    }
}

struct JournalReviewDay: Identifiable, Sendable {
    var day: String
    var sessions: [WorkoutSession]
    var entries: [DietEntry]
    var measurements: [BodyMeasurement]
    var id: String { day }
    var training: TrainingSummary { TrainingSummary(sessions: sessions) }
    var nutrition: NutritionSummary { NutritionSummary(entries: entries) }
    var hasRecords: Bool { !sessions.isEmpty || !entries.isEmpty || !measurements.isEmpty }
}

struct JournalReview: Sendable {
    var days: [JournalReviewDay]
    var trainingDays: Int { days.filter { $0.training.workouts > 0 }.count }
    var workouts: Int { days.reduce(0) { $0 + $1.training.workouts } }
    var completedSets: Int { days.reduce(0) { $0 + $1.training.completedSets } }
    var dietDays: Int { days.filter { !$0.entries.isEmpty }.count }
    var completeNutrientDays: Int { days.filter { !$0.entries.isEmpty && $0.nutrition.missingFields == 0 }.count }
    var knownEnergyAverage: Double? {
        let values = days.compactMap { $0.nutrition.energy.known }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    init(dates: [String], sessions: [WorkoutSession], entries: [DietEntry], measurements: [BodyMeasurement]) {
        let wanted = Set(dates)
        let workouts = Dictionary(grouping: sessions.filter {
            $0.stamp.deletedAt == nil && [.completed, .abandoned].contains($0.status) && wanted.contains($0.started.localDate)
        }, by: { $0.started.localDate })
        let diet = Dictionary(grouping: entries.filter { $0.stamp.deletedAt == nil && wanted.contains($0.occurred.localDate) }, by: { $0.occurred.localDate })
        let body = BodyMetric.allCases.flatMap { BodySummary.dailyLatest(measurements, metric: $0) }
        let readings = Dictionary(grouping: body.filter { wanted.contains($0.occurred.localDate) }, by: { $0.occurred.localDate })
        days = dates.map { day in
            JournalReviewDay(day: day, sessions: (workouts[day] ?? []).sorted { $0.started.instant > $1.started.instant },
                entries: (diet[day] ?? []).sorted { $0.occurred.instant < $1.occurred.instant },
                measurements: (readings[day] ?? []).sorted { $0.metric.rawValue < $1.metric.rawValue })
        }
    }

    static func week(containing date: Date, timeZone: TimeZone = .current) -> [String] {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: date)
        let start = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: date) ?? date
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            .map { RecordMoment.day($0, timeZoneID: timeZone.identifier) }
    }
}
