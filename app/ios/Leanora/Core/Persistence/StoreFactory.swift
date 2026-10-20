import Foundation
import SwiftData

enum StoreFactory {
    static func memory() throws -> ModelContainer {
        try ModelContainer(for: Schema(versionedSchema: AppSchemaV2.self), migrationPlan: AppSchemaMigrationPlan.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    static func applicationDirectory(testing: Bool = false) throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        return base.appendingPathComponent(testing ? "LeanoraUITesting" : "Leanora", isDirectory: true)
    }

    static func open(directory: URL, beforeOpen: () throws -> Void = {}) throws -> ModelContainer {
        try protect(directory)
        let url = directory.appendingPathComponent("Leanora.store")
        let recoveries = try recoveryCopies(in: directory)
        guard !FileManager.default.fileExists(atPath: directory.appendingPathComponent("Restore.pending").path),
              FileManager.default.fileExists(atPath: url.path) || recoveries.isEmpty else {
            throw DataProblem.invalid("恢复尚未完成，请选择完整恢复副本")
        }
        // Only called before any context/container opens this store. Preserve SQLite
        // and its WAL together; never delete a database in a migration catch block.
        if FileManager.default.fileExists(atPath: url.path) { _ = try makeRecovery(in: directory) }
        try beforeOpen()
        let configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Schema(versionedSchema: AppSchemaV2.self), migrationPlan: AppSchemaMigrationPlan.self,
                                           configurations: configuration)
        try protect(directory)
        // Failed opens never prune a potentially useful older recovery.
        for old in try recoveryCopies(in: directory).dropFirst(3) { try FileManager.default.removeItem(at: old) }
        return container
    }

    @discardableResult static func makeRecovery(in directory: URL) throws -> URL {
        let fm = FileManager.default
        let recoveryRoot = directory.appendingPathComponent("Recovery", isDirectory: true)
        try protect(recoveryRoot)
        let target = recoveryRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try protect(target)
        do {
            for name in ["Leanora.store", "Leanora.store-wal", "Leanora.store-shm"] {
                let source = directory.appendingPathComponent(name)
                if fm.fileExists(atPath: source.path) { try fm.copyItem(at: source, to: target.appendingPathComponent(name)) }
            }
            try protect(target)
            return target
        } catch {
            // A partial copy is never offered as a recovery generation.
            try? fm.removeItem(at: target)
            throw error
        }
    }

    static func recoveryCopies(in directory: URL) throws -> [URL] {
        let root = directory.appendingPathComponent("Recovery")
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey])
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("Leanora.store").path) }
            .sorted { ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) >
                ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
    }

    // Must be invoked with no open container (startup recovery only). The current
    // files are preserved in another generation before a selected copy is restored.
    static func restoreRecovery(_ recovery: URL, in directory: URL) throws {
        let fm = FileManager.default
        let allowed = directory.appendingPathComponent("Recovery").standardizedFileURL.path + "/"
        guard recovery.standardizedFileURL.path.hasPrefix(allowed),
              fm.fileExists(atPath: recovery.appendingPathComponent("Leanora.store").path) else { throw DataProblem.invalid("恢复副本") }
        let stage = directory.appendingPathComponent("Restore-\(UUID())", isDirectory: true)
        try protect(stage)
        defer { try? fm.removeItem(at: stage) }
        for name in ["Leanora.store", "Leanora.store-wal", "Leanora.store-shm"] {
            let file = recovery.appendingPathComponent(name)
            if fm.fileExists(atPath: file.path) { try fm.copyItem(at: file, to: stage.appendingPathComponent(name)) }
        }
        // Do not prune the user-selected recovery while making this safety copy.
        let saved = directory.appendingPathComponent("BeforeRestore-\(UUID())", isDirectory: true)
        try protect(saved)
        let names = ["Leanora.store", "Leanora.store-wal", "Leanora.store-shm"]
        let marker = directory.appendingPathComponent("Restore.pending")
        // A process termination between file moves must never be interpreted as a
        // brand-new empty library on the next launch.
        try Data(saved.lastPathComponent.utf8).write(to: marker, options: .atomic)
        var moved: [String] = [], installed: [String] = []
        do {
            for name in names {
                let original = directory.appendingPathComponent(name)
                if fm.fileExists(atPath: original.path) {
                    try fm.moveItem(at: original, to: saved.appendingPathComponent(name)); moved.append(name)
                }
            }
            for name in names {
                let source = stage.appendingPathComponent(name)
                if fm.fileExists(atPath: source.path) {
                    try fm.copyItem(at: source, to: directory.appendingPathComponent(name)); installed.append(name)
                }
            }
            try protect(directory)
            try fm.removeItem(at: marker)
        } catch {
            for name in installed { try? fm.removeItem(at: directory.appendingPathComponent(name)) }
            for name in moved { try? fm.moveItem(at: saved.appendingPathComponent(name), to: directory.appendingPathComponent(name)) }
            // If the OS also refuses rollback, the originals still exist in saved.
            throw error
        }
    }

    static func protect(_ directory: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        #if os(iOS)
        try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        #endif
        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil) {
            for case var item as URL in enumerator {
                try item.setResourceValues(values)
                #if os(iOS)
                try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: item.path)
                #endif
            }
        }
    }
}
