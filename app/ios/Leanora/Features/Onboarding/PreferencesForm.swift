import SwiftUI

struct PreferencesForm: View {
    @Binding var weight: WeightUnit
    @Binding var distance: DistanceUnit
    @Binding var days: Int
    @Binding var energy: String
    var energyFocus: FocusState<Bool>.Binding

    var body: some View {
        Section {
            Picker("重量单位", selection: $weight) {
                ForEach(WeightUnit.allCases) { Text($0.title).tag($0) }
            }.accessibilityIdentifier("preferences.weight")
            Picker("距离单位", selection: $distance) {
                ForEach(DistanceUnit.allCases) { Text($0.title).tag($0) }
            }.accessibilityIdentifier("preferences.distance")
        } header: { Text("常用单位") }

        Section {
            Picker("每周训练", selection: $days) {
                Text("暂不设置").tag(0)
                ForEach(1...7, id: \.self) { Text("\($0) 天").tag($0) }
            }.accessibilityIdentifier("preferences.days")
            LabeledContent("每日热量目标") {
                HStack {
                    TextField("选填", text: $energy)
                        .keyboardType(.numberPad)
                        .focused(energyFocus)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("preferences.energy")
                    if !energy.isEmpty {
                        Button {
                            energy = ""
                            energyFocus.wrappedValue = true
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("清除热量目标")
                        .accessibilityIdentifier("preferences.clearEnergy")
                    }
                    Text("kcal").foregroundStyle(.secondary)
                }
            }
        } header: { Text("你的目标 · 可选") }
        footer: { Text("按自己的计划填写，也可以稍后在「我的」中修改。") }
    }
}

struct KeyboardDismissBar: ViewModifier {
    var energyFocus: FocusState<Bool>.Binding
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if energyFocus.wrappedValue {
                HStack {
                    Spacer()
                    Button("完成") { energyFocus.wrappedValue = false }
                        .font(.headline).frame(minHeight: 44)
                        .accessibilityIdentifier("preferences.keyboardDone")
                }
                .padding(.horizontal, 24).padding(.vertical, 4)
                .background(LeanoraTheme.surface)
            }
        }
    }
}

struct PreferencesEditorView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var weight: WeightUnit = .kilograms
    @State private var distance: DistanceUnit = .kilometers
    @State private var days = 0
    @State private var energy = ""
    @State private var error: String?
    @FocusState private var energyFocused: Bool

    var body: some View {
        Form {
            PreferencesForm(weight: $weight, distance: $distance, days: $days, energy: $energy, energyFocus: $energyFocused)
            if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("preferences.error") }
        }
        .scrollContentBackground(.hidden)
        .background(LeanoraTheme.canvas)
        .modifier(KeyboardDismissBar(energyFocus: $energyFocused))
        .navigationTitle("单位与目标")
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    do {
                        try preferences.save(weight: weight, distance: distance, days: days == 0 ? nil : days, energyText: energy)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }.accessibilityIdentifier("preferences.save")
            }
        }
        .onAppear {
            weight = preferences.values.weightUnit
            distance = preferences.values.distanceUnit
            days = preferences.values.weeklyTrainingDays ?? 0
            energy = preferences.values.dailyEnergyGoal.map(String.init) ?? ""
        }
    }
}
