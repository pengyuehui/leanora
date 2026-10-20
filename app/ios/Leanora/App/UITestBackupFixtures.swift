#if DEBUG
import Foundation

enum UITestBackupFixtures {
    static func create(for repository: AppModelActor) async throws {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--uitesting"), arguments.contains("--backup-fixtures") else { return }
        let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var records = try await repository.snapshot()
        let stamp = RecordStamp(id: UUID(uuidString: "00000000-0000-4000-8000-000000000999")!, revision: 1,
                                createdAt: Date(timeIntervalSince1970: 1_792_483_200), updatedAt: Date(timeIntervalSince1970: 1_792_483_200))
        records.append(.diet(DietEntry(stamp: stamp, meal: .snack, name: "测试快速记录", nutrients: Nutrients(energyKcal: 200))))
        let profile = records.first { $0.kind == "profile" }!
        try RecordCoding.encode(BackupDocument(profileID: profile.id, records: records))
            .write(to: directory.appendingPathComponent("Leanora-valid.json"), options: .atomic)
        try Data("{invalid-json".utf8).write(to: directory.appendingPathComponent("Leanora-invalid.json"), options: .atomic)
        try StoreFactory.protect(directory)
    }
}
#endif
