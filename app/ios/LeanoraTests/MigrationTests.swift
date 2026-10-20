import XCTest
import SwiftData
import SQLite3
@testable import Leanora

@MainActor final class MigrationTests: XCTestCase {
    private func makeV1Fixture(in directory: URL) throws -> [BusinessRecord] {
        try autoreleasepool {
        try StoreFactory.protect(directory)
        let sourceDirectory = directory.appendingPathComponent("FixtureSource")
        try StoreFactory.protect(sourceDirectory)
        let sourceURL = sourceDirectory.appendingPathComponent("Leanora.store")
        let configuration = ModelConfiguration(url: sourceURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Schema(versionedSchema: AppSchemaV1.self), configurations: configuration)
        let context = ModelContext(container); context.autosaveEnabled = false
        let records = DataFixtures.records()
        for record in records {
            context.insert(AppSchemaV1.StoredRecord(key: "business:\(record.id)", kind: "business", payload: try RecordCoding.encode(record)))
        }
        try context.save()
        // Materialize a closed SQLite fixture using SQLite's consistent backup
        // API. Core Data may checkpoint/history-clean its original after save;
        // that must not mutate the fixture under the migration-failure test.
        var source: OpaquePointer?, destination: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              sqlite3_open(directory.appendingPathComponent("Leanora.store").path, &destination) == SQLITE_OK else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(source); sqlite3_close(destination) }
        guard let backup = sqlite3_backup_init(destination, "main", source, "main") else { throw CocoaError(.fileReadUnknown) }
        let result = sqlite3_backup_step(backup, -1)
        sqlite3_backup_finish(backup)
        guard result == SQLITE_DONE else { throw CocoaError(.fileReadUnknown) }
        return records
        }
    }

    func testV1DiskFixtureMigratesToV2WithoutChangingIDsOrSnapshots() async throws {
        let directory = DataFixtures.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try makeV1Fixture(in: directory)
        let container = try StoreFactory.open(directory: directory)
        XCTAssertEqual(container.schema.version, AppSchemaV2.versionIdentifier)
        let migrated = AppModelActor(modelContainer: container)
        let records = try await migrated.snapshot()
        XCTAssertEqual(try RecordCoding.fingerprint(original), try RecordCoding.fingerprint(records))
        let backup = try await migrated.exportBackup()
        XCTAssertEqual(try BackupService.decode(backup.data).profileID, DataFixtures.stamp(1).id)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("Recovery"), includingPropertiesForKeys: nil).isEmpty)
    }

    func testOpenFailureKeepsOriginalBytesAndRecoverableV1Copy() async throws {
        let directory = DataFixtures.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try makeV1Fixture(in: directory)
        let storeURL = directory.appendingPathComponent("Leanora.store")
        let before = try Data(contentsOf: storeURL)
        XCTAssertThrowsError(try StoreFactory.open(directory: directory, beforeOpen: { throw CocoaError(.fileReadCorruptFile) }))
        XCTAssertEqual(try Data(contentsOf: storeURL), before)
        let recovery = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("Recovery"), includingPropertiesForKeys: nil).first)
        XCTAssertEqual(try Data(contentsOf: recovery.appendingPathComponent("Leanora.store")), before)
        try StoreFactory.restoreRecovery(recovery, in: directory)
        let reopened = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        let recovered = try await reopened.snapshot()
        XCTAssertEqual(try RecordCoding.fingerprint(recovered), try RecordCoding.fingerprint(original))
    }

    func testCorruptStoreIsNotDeletedOrSilentlyReplaced() throws {
        let directory = DataFixtures.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try StoreFactory.protect(directory)
        let url = directory.appendingPathComponent("Leanora.store")
        let corrupt = Data("deliberately corrupt database".utf8)
        try corrupt.write(to: url)
        XCTAssertThrowsError(try StoreFactory.open(directory: directory))
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testInterruptedRestoreCannotBeOpenedAsEmptyLibrary() async throws {
        let directory = DataFixtures.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let records = try makeV1Fixture(in: directory)
        let recovery = try StoreFactory.makeRecovery(in: directory)
        let original = directory.appendingPathComponent("Leanora.store")
        try FileManager.default.moveItem(at: original, to: directory.appendingPathComponent("BeforeInterruptedRestore.store"))
        try Data("interrupted".utf8).write(to: directory.appendingPathComponent("Restore.pending"))
        XCTAssertThrowsError(try StoreFactory.open(directory: directory))
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        try StoreFactory.restoreRecovery(recovery, in: directory)
        let actor = AppModelActor(modelContainer: try StoreFactory.open(directory: directory))
        let restored = try await actor.snapshot()
        XCTAssertEqual(try RecordCoding.fingerprint(restored), try RecordCoding.fingerprint(records))
    }
}
