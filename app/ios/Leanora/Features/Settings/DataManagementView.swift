import SwiftUI
import UniformTypeIdentifiers

struct LeanoraBackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw DataProblem.invalid("备份文件") }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct DataManagementView: View {
    @Environment(DataStoreController.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @State private var count = 0
    @State private var profileID = ""
    @State private var busy = false
    @State private var error: String?
    @State private var notice: String?
    @State private var importing = false
    @State private var exporting = false
    @State private var exportFile = LeanoraBackupFile()
    @State private var exportFingerprint: String?
    @State private var successfulExportFingerprint: String?
    @State private var preview: PreparedImport?
    @State private var acceptNewer = false
    @State private var confirmingReplacement = false
    @State private var reconciliationRequired = false

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            Section {
                LabeledContent("业务记录", value: "\(count) 条").accessibilityIdentifier("backup.count")
                Text("身份：\(profileID)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            } header: { Text("本机资料库") } footer: { Text("条数包含身份、模板、目标、自定义资料与删除标记；不包含 Apple Health 缓存。") }
            if let message = error ?? store.preferenceError {
                Section { Label(message, systemImage: "exclamationmark.triangle").accessibilityIdentifier("backup.error") }
            }
            if let notice {
                Section { Text(notice).accessibilityIdentifier("backup.notice") }
            }
            if reconciliationRequired {
                Section { Label("资料曾从备份恢复。健康写入仍暂停，后续需重新连接并核对已有样本。", systemImage: "heart.slash") }
            }
            Section {
                Button { Task { await prepareExport() } } label: {
                    Label("导出 JSON 备份", systemImage: "square.and.arrow.up")
                }.accessibilityIdentifier("backup.export")
                Button { importing = true } label: {
                    Label("选择 JSON 备份", systemImage: "square.and.arrow.down")
                }.accessibilityIdentifier("backup.import")
            } footer: {
                Text("备份含敏感的训练、饮食和身体资料。导出为未加密 JSON，请选择可信的位置。备份保留业务 ID，不包含健康样本、游标或同步任务。")
            }.disabled(busy || store.repository == nil)
            if let preview {
                Section("导入预览") {
                    LabeledContent("新增", value: "\(preview.incoming)")
                    LabeledContent("较新版本", value: "\(preview.newer)")
                    LabeledContent("较旧版本 · 跳过", value: "\(preview.older)")
                    LabeledContent("相同内容 · 跳过", value: "\(preview.identical)")
                    LabeledContent("同版本冲突 · 保留本机", value: "\(preview.conflicts)")
                    if preview.differentIdentity {
                        Text("此备份属于另一身份。替换会移除当前业务记录与设备健康缓存，Apple Health 中的样本会保留。请先导出当前数据。")
                        Button("确认整库替换", role: .destructive) { confirmingReplacement = true }
                            .disabled(successfulExportFingerprint != preview.originalFingerprint)
                            .accessibilityIdentifier("backup.replace")
                    } else {
                        if preview.newer > 0 { Toggle("采用备份中较新的版本", isOn: $acceptNewer).accessibilityIdentifier("backup.acceptNewer") }
                        Button("确认导入") { Task { await commit(preview, replace: false) } }
                            .accessibilityIdentifier("backup.confirm")
                    }
                    Button("取消预览", role: .cancel) { self.preview = nil }.accessibilityIdentifier("backup.cancel")
                }.disabled(busy).id("import-preview")
            }
            Section {
                Text("导入限制：50MB、10 万条业务记录。预检失败不会修改本机资料。导入后暂不生成健康写入任务，后续需重新连接健康并核对样本。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if busy { ProgressView("正在处理…").accessibilityIdentifier("backup.busy") }
        }
        .onChange(of: preview != nil) { _, hasPreview in
            if hasPreview { proxy.scrollTo("import-preview", anchor: .top) }
        }
        .navigationTitle("数据管理").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden).background(LeanoraTheme.canvas)
        .task { await refresh() }
        .fileExporter(isPresented: $exporting, document: exportFile, contentType: .json,
                      defaultFilename: "Leanora-\(RecordMoment().localDate)") { result in
            switch result {
            case .success:
                successfulExportFingerprint = exportFingerprint
                notice = "备份已导出，请妥善保管。"
            case .failure: error = "备份未能导出，请重试。"
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): Task { await load(url) }
            case .failure: error = "备份文件未能打开，请重试。"
            }
        }
        .confirmationDialog("替换当前资料库？", isPresented: $confirmingReplacement, titleVisibility: .visible) {
            Button("已导出，整库替换", role: .destructive) {
                if let preview { Task { await commit(preview, replace: true) } }
            }
        } message: { Text("当前资料会被备份内容替换。不会删除 Apple Health 中的样本。") }
        }
    }

    private func refresh() async {
        guard let repository = store.repository else { return }
        do {
            let records = try await repository.snapshot()
            count = records.reduce(0) { $0 + 1 + $1.nestedIDs.count }
            profileID = records.first(where: { $0.kind == "profile" })?.id.uuidString ?? ""
            reconciliationRequired = try await repository.runtimeSnapshot().contains(.reconciliationRequired(true))
        } catch { self.error = error.localizedDescription }
    }
    private func prepareExport() async {
        guard let repository = store.repository else { return }
        busy = true; error = nil; defer { busy = false }
        await store.synchronize(preferences.values)
        guard store.preferenceError == nil else { return }
        do {
            let backup = try await repository.exportBackup()
            exportFile = LeanoraBackupFile(data: backup.data); exportFingerprint = backup.fingerprint
            exporting = true
        } catch { self.error = error.localizedDescription }
    }
    private func load(_ url: URL) async {
        guard let repository = store.repository else { return }
        busy = true; error = nil; notice = nil; preview = nil; defer { busy = false }
        do {
            let data = try await Task.detached {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                return try BackupService.readFile(url)
            }.value
            preview = try await repository.prepareImport(data); acceptNewer = false
        } catch { self.error = error.localizedDescription }
    }
    private func commit(_ preview: PreparedImport, replace: Bool) async {
        guard let repository = store.repository else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            let result = try await repository.importBackup(preview, acceptNewer: acceptNewer, replace: replace,
                                                            exportedFingerprint: successfulExportFingerprint)
            // Preferences are small UI caches. Restore them from the authoritative
            // business profile only after the database transaction succeeds.
            try await store.restorePreferences(from: repository, into: preferences)
            self.preview = nil; successfulExportFingerprint = nil
            notice = "导入完成：新增 \(result.inserted)，更新 \(result.updated)，跳过 \(result.skipped)。健康写入保持暂停，待重新连接并核对。"
            await refresh()
            await store.training?.refresh()
            await store.journal?.refresh()
        } catch { self.error = error.localizedDescription }
    }
}
