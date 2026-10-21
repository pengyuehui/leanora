import SwiftUI

struct HealthWorkoutAssociationView: View {
    let workout: ExternalWorkout
    @Environment(DataStoreController.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?
    @State private var primary = HealthWorkoutPrimary.local
    @State private var error: String?
    private var matches: [WorkoutSession] { (store.training?.sessions ?? []).filter { HealthAggregation.overlaps($0, workout) } }
    var body: some View {
        Form {
            Section("可能重复的训练") {
                Text("关联不会删除任意来源。下面的时长只采用你选择的主记录，不相加；逐组容量仍只来自本机训练。")
                ForEach(matches) { session in
                    Button { selected = session.id } label: {
                        HStack { Text(session.name); Spacer(); if selected == session.id { Image(systemName: "checkmark") } }.frame(minHeight: 44)
                    }
                }
            }
            Section("用于关联摘要的主记录") {
                Picker("主记录", selection: $primary) { Text("本机训练").tag(HealthWorkoutPrimary.local); Text("健康来源").tag(HealthWorkoutPrimary.health) }
                if let session = matches.first(where: { $0.id == selected }) {
                    Text("有效时长 \(Int(HealthAggregation.primaryDuration(local: session, external: workout, choice: primary) / 60)) 分钟")
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("关联训练").navigationBarTitleDisplayMode(.inline)
            .task { selected = matches.first?.id }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") {
                    guard let selected else { return }
                    Task {
                        do { try await store.repository?.associateHealthWorkout(HealthWorkoutAssociation(sampleUUID: workout.sampleUUID, businessID: selected, primary: primary)); await store.healthSync?.refresh(); dismiss() }
                        catch { self.error = "关联未保存，请重试。" }
                    }
                }.disabled(selected == nil) }
            }
    }
}
