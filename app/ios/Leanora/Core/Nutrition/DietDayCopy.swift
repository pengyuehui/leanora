import Foundation

enum DietDayCopy {
    static func prepare(entries: [DietEntry], sourceDay: String, meals: Set<Meal>, destination: Date,
                        timeZoneID: String = TimeZone.current.identifier) throws -> [DietEntry] {
        try DomainValidation.day(sourceDay)
        guard let zone = TimeZone(identifier: timeZoneID), destination.timeIntervalSince1970.isFinite else { throw DataProblem.invalid("复制日期或时区") }
        guard sourceDay != RecordMoment.day(destination, timeZoneID: timeZoneID) else { throw DataProblem.invalid("请选择与来源不同的目标日期") }
        let originals = entries.filter { $0.stamp.deletedAt == nil && $0.occurred.localDate == sourceDay && meals.contains($0.meal) }
            .sorted { $0.occurred.instant == $1.occurred.instant ? $0.stamp.id.uuidString < $1.stamp.id.uuidString : $0.occurred.instant < $1.occurred.instant }
        guard (1...200).contains(originals.count) else { throw DataProblem.invalid("请选择有记录的餐次，每次最多复制 200 项") }
        var targetCalendar = Calendar(identifier: .gregorian); targetCalendar.timeZone = zone
        return try originals.map { original in
            try DomainValidation.moment(original.occurred)
            var sourceCalendar = Calendar(identifier: .gregorian)
            sourceCalendar.timeZone = TimeZone(identifier: original.occurred.timeZoneID)!
            let clock = sourceCalendar.dateComponents([.hour, .minute, .second], from: original.occurred.instant)
            guard let date = targetCalendar.date(bySettingHour: clock.hour!, minute: clock.minute!, second: clock.second!, of: destination,
                matchingPolicy: .nextTime, repeatedTimePolicy: .first),
                RecordMoment.day(date, timeZoneID: timeZoneID) == RecordMoment.day(destination, timeZoneID: timeZoneID) else { throw DataProblem.invalid("目标日的本地时刻") }
            var copy = original; copy.stamp = RecordStamp(); copy.occurred = RecordMoment(date, timeZoneID: timeZoneID)
            try MealTemplateItem(entry: copy, order: 0).validate()
            return copy
        }
    }
}
