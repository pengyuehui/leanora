import SwiftUI

struct OnboardingView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var weight: WeightUnit = .kilograms
    @State private var distance: DistanceUnit = .kilometers
    @State private var days = 0
    @State private var energy = ""
    @State private var error: String?
    @FocusState private var energyFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step > 0 {
                    HStack {
                        Button { move(to: step - 1) } label: { Label("上一步", systemImage: "arrow.left") }
                            .frame(minHeight: 44)
                        Spacer()
                        Text("\(step + 1) / 3").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }.padding(.horizontal, 24)
                }
                Group {
                    switch step {
                    case 0: welcome
                    case 1: setup
                    default: health
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(LeanoraTheme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                weight = preferences.values.weightUnit
                distance = preferences.values.distanceUnit
                days = preferences.values.weeklyTrainingDays ?? 0
                energy = preferences.values.dailyEnergyGoal.map(String.init) ?? ""
            }
        }
    }

    private func move(to step: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { self.step = step }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 12) {
                    LeanoraMark(size: 44)
                    Text("leanora").font(.title2.weight(.semibold)).tracking(-1)
                }.padding(.top, 28)
                SectionEyebrow(text: "属于你的训练与饮食日记")
                Text("每一次，\n都算数。")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("onboarding.welcome")
                Text("把训练、饮食和身体的变化，\n留在一份从容的记录里。")
                    .font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Divider().padding(.vertical, 4)
                VStack(spacing: 0) {
                    FeatureLine(symbol: "dumbbell", title: "专注每一组", detail: "让每次训练都有迹可循。")
                    FeatureLine(symbol: "fork.knife", title: "看见日常饮食", detail: "用自己的节奏，慢慢建立习惯。")
                    FeatureLine(symbol: "heart", title: "由你掌握数据", detail: "无需注册，健康访问按需开启。")
                }
                Button("开始设置") { move(to: 1) }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("onboarding.start")
                Text("不必一次准备好所有事情。")
                    .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }.padding(28)
        }
    }

    private var setup: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    SectionEyebrow(text: "先从你的习惯开始")
                    Text("用你熟悉的方式。")
                        .font(.system(.title, design: .serif, weight: .semibold))
                        .accessibilityIdentifier("onboarding.preferences")
                    Text("选择单位；目标可以先留空。")
                        .foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }.listRowBackground(Color.clear)
            PreferencesForm(weight: $weight, distance: $distance, days: $days, energy: $energy, energyFocus: $energyFocused)
            if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("preferences.error") }
            Button("下一步") {
                do {
                    try preferences.save(weight: weight, distance: distance, days: days == 0 ? nil : days, energyText: energy)
                    error = nil
                    move(to: 2)
                } catch { self.error = error.localizedDescription }
            }.buttonStyle(PrimaryButtonStyle()).listRowBackground(Color.clear)
                .accessibilityIdentifier("onboarding.next")
        }.scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .modifier(KeyboardDismissBar(energyFocus: $energyFocused))
    }

    private var health: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "heart.text.clipboard").font(.system(size: 52)).foregroundStyle(LeanoraTheme.accent).accessibilityHidden(true)
                SectionEyebrow(text: "按需开启 · 随时调整")
                Text("连接健康，\n也可以稍后再说。")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("onboarding.health")
                Text("由你选择可以读取和写入的数据类型。跳过不会影响进入 App。")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                NavigationLink { HealthConnectionView() } label: {
                    Label("设置 Apple Health 访问", systemImage: "heart")
                }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("onboarding.connectHealth")
                Button("进入 Leanora") { preferences.finishOnboarding() }
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                    .accessibilityIdentifier("onboarding.finish")
                NavigationLink("隐私与数据说明") { PrivacyView() }
                    .font(.footnote).frame(maxWidth: .infinity, minHeight: 44)
            }.padding(28).padding(.top, 24)
        }
    }
}
