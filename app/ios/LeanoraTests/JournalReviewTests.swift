import XCTest
@testable import Leanora

final class JournalReviewTests: XCTestCase {
    func testMonthCalendarKeepsMondayColumnsAndLeapDaysAcrossDST() throws {
        for zone in ["Asia/Shanghai", "America/Los_Angeles", "America/Sao_Paulo"] {
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
            for year in [2024, 2026, 2028] {
                for month in 1...12 {
                    let date = try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: 15, hour: 12)))
                    let days = JournalMonth.days(containing: date, timeZone: calendar.timeZone)
                    XCTAssertEqual(days.count % 7, 0); XCTAssertLessThanOrEqual(days.count, 42)
                    XCTAssertEqual(Set(days.map(\.day)).count, days.count)
                    XCTAssertEqual(calendar.component(.weekday, from: try XCTUnwrap(days.first?.date)), 2)
                    XCTAssertEqual(days.filter(\.isInMonth).count, calendar.range(of: .day, in: .month, for: date)?.count)
                    for index in 1..<days.count {
                        XCTAssertEqual(calendar.dateComponents([.day], from: days[index - 1].date, to: days[index].date).day, 1)
                    }
                }
            }
        }
    }
    func testWeeksCrossYearAndDSTWithoutMissingDates() throws {
        let formatter = ISO8601DateFormatter()
        let ny = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        XCTAssertEqual(JournalReview.week(containing: formatter.date(from: "2026-01-01T12:00:00Z")!, timeZone: .gmt),
            ["2025-12-29", "2025-12-30", "2025-12-31", "2026-01-01", "2026-01-02", "2026-01-03", "2026-01-04"])
        XCTAssertEqual(JournalReview.week(containing: formatter.date(from: "2026-03-08T18:00:00Z")!, timeZone: ny),
            ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06", "2026-03-07", "2026-03-08"])
    }

    func testRecordCoverageUsesStoredDatesAndUnknownValuesRemainPartial() {
        let moment = RecordMoment(DataFixtures.date, timeZoneID: "Pacific/Kiritimati")
        let day = moment.localDate
        var deleted = DietEntry(occurred: moment, meal: .dinner, nutrients: Nutrients(energyKcal: 999))
        deleted.stamp.deletedAt = Date()
        let a = DietEntry(occurred: moment, meal: .lunch, nutrients: Nutrients(energyKcal: 200, proteinGrams: 10, carbohydrateGrams: 20, fatGrams: 5))
        let b = DietEntry(occurred: moment, meal: .snack, nutrients: Nutrients(energyKcal: 100))
        let summary = JournalReview(dates: [day, "2099-01-01"], sessions: [], entries: [a,b,deleted], measurements: [])
        XCTAssertEqual(summary.dietDays, 1); XCTAssertEqual(summary.completeNutrientDays, 0)
        XCTAssertEqual(summary.knownEnergyAverage, 300); XCTAssertEqual(summary.days[0].nutrition.energy.known, 300)
        XCTAssertFalse(summary.days[1].hasRecords); XCTAssertNil(summary.days[1].nutrition.energy.known)
        XCTAssertEqual(summary.days[0].nutrition.protein.missing, 1)
        XCTAssertEqual(JournalReview(dates: [day], sessions: [], entries: [a], measurements: []).completeNutrientDays, 1)
    }

    func testAbandonedTrainingIsVisibleButDoesNotCountAndLatestBodyIsSelected() {
        let date = DataFixtures.date, day = RecordMoment(date).localDate
        let completed = WorkoutSession(started: RecordMoment(date), endedAt: date, status: .completed, name: "完成")
        var removed = completed; removed.stamp = RecordStamp(); removed.stamp.deletedAt = date
        let abandoned = WorkoutSession(started: RecordMoment(date), endedAt: date, status: .abandoned, name: "放弃")
        let active = WorkoutSession(started: RecordMoment(date), status: .active, name: "进行中")
        let first = BodyMeasurement(occurred: RecordMoment(date), metric: .weightKg, value: 70)
        let last = BodyMeasurement(occurred: RecordMoment(date.addingTimeInterval(10)), metric: .weightKg, value: 71)
        let review = JournalReview(dates: [day], sessions: [completed,removed,abandoned,active], entries: [], measurements: [first,last])
        XCTAssertEqual(review.workouts, 1); XCTAssertEqual(review.trainingDays, 1)
        XCTAssertEqual(review.days[0].sessions.count, 2); XCTAssertEqual(review.days[0].measurements, [last])
        XCTAssertNil(review.knownEnergyAverage)
    }
}
